/*
 *  Copyright (C) 2016-present Prominic.NET, Inc.
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the Server Side Public License, version 1,
 *  as published by MongoDB, Inc.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *  Server Side Public License for more details.
 *
 *  You should have received a copy of the Server Side Public License
 *  along with this program. If not, see
 *
 *  http://www.mongodb.com/licensing/server-side-public-license
 *
 *  As a special exception, the copyright holders give permission to link the
 *  code of portions of this program with the OpenSSL library under certain
 *  conditions as described in each individual source file and distribute
 *  linked combinations including the program with the OpenSSL library. You
 *  must comply with the Server Side Public License in all respects for
 *  all of the code used other than as permitted herein. If you modify file(s)
 *  with this exception, you may extend this exception to your version of the
 *  file(s), but you are not obligated to do so. If you do not wish to do so,
 *  delete this exception statement from your version. If you delete this
 *  exception statement from all source files in the program, then also delete
 *  it in the license file.
 */

package superhuman.downloaders;

import champaign.core.ds.ChainedList;
import champaign.core.logging.Logger;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.events.ProgressEvent;
import openfl.net.URLLoader;
import openfl.net.URLLoaderDataFormat;
import openfl.net.URLRequest;
import openfl.net.URLStream;
import openfl.net.URLRequestHeader;
import openfl.net.URLRequestMethod;
import openfl.utils.ByteArray;
import superhuman.config.SuperHumanSecrets;
import superhuman.server.cache.SuperHumanCachedFile;
import superhuman.server.cache.SuperHumanFileCache;
import superhuman.config.SuperHumanHashes;
import openfl.Lib;
import sys.FileSystem;
import sys.io.File;

/**
 * NetworkExecutor - A specialized executor for handling HTTP operations asynchronously
 * This allows HTTP operations to be scheduled like other async tasks
 */
class NetworkExecutor extends prominic.sys.io.AbstractExecutor {
    // The URL to request
    private var _url:String;
    // The method (GET or POST)
    private var _method:String;
    // Request headers
    private var _headers:Map<String, String>;
    // Post data (for POST requests)
    private var _postData:String;
    // Whether request is in binary mode
    private var _binary:Bool;
    // Bytes loaded (for progress reporting)
    private var _bytesLoaded:Int = 0;
    // Total bytes (for progress reporting) 
    private var _bytesTotal:Int = 0;
    // Response data
    private var _responseData:Dynamic;
    // Response headers
    private var _responseHeaders:Map<String, String>;
    // Progress handler for progress event
    private var _onProgress:ChainedList<(NetworkExecutor, Float)->Void, NetworkExecutor>;
    // Tracks if a redirect is being followed
    private var _followRedirect:Bool = false;
    // Tracking for redirect chain 
    private var _redirectCount:Int = 0;
    
    /**
     * Create a new NetworkExecutor
     * @param url The URL to request
     * @param method The HTTP method (GET or POST)
     * @param headers Optional request headers
     * @param postData Optional post data (for POST requests)
     * @param binary Whether to handle response as binary
     */
    public function new(url:String, method:String = "GET", ?headers:Map<String, String>, ?postData:String, binary:Bool = false) {
        super();
        _url = url;
        _method = method;
        _headers = headers != null ? headers : new Map<String, String>();
        _postData = postData;
        _binary = binary;
        _onProgress = new ChainedList(this);
    }
    
    /**
     * Event fired during progress
     */
    public var onProgress(get, never):ChainedList<(NetworkExecutor, Float)->Void, NetworkExecutor>;
    function get_onProgress() return _onProgress;
    
    /**
     * Get response data
     */
    public var responseData(get, never):Dynamic;
    private function get_responseData() return _responseData;
    
    /**
     * Get response headers
     */
    public var responseHeaders(get, never):Map<String, String>;
    private function get_responseHeaders() return _responseHeaders;
    
    /**
     * Execute the HTTP request asynchronously
     */
    public function execute(?extraArgs:Array<String>, ?workingDirectory:String):NetworkExecutor {
        // Don't start if already running
        if (_running) return this;
        
        _startTime = Sys.time();
        _running = true;
        _hasErrors = false;
        
        // Trigger start event
        for (f in _onStart) f(this);
        
        // Use Timer.delay to ensure non-blocking operation
        haxe.Timer.delay(function() {
            // Perform the actual HTTP request
            if (_binary) {
                _executeBinaryRequest();
            } else {
                _executeTextRequest();
            }
        }, 50); // Short delay to allow UI updates
        
        return this;
    }
    
    /**
     * Execute text-based HTTP request
     */
    private function _executeTextRequest():Void {
        var http = new haxe.Http(_url);
        
        // Set headers
        for (key in _headers.keys()) {
            http.setHeader(key, _headers.get(key));
        }
        
        // Set callbacks
        http.onData = function(data:String) {
            _responseData = data;
            _finalizeExecution(0);
        };
        
        http.onError = function(error:String) {
            _hasErrors = true;
            for (f in _onStdErr) f(this, error);
            _finalizeExecution(1);
        };
        
        http.onStatus = function(status:Int) {
            if (status >= 300 && status < 400 && _followRedirect) {
                // Handle redirects
                _handleRedirect(http.responseHeaders);
                return;
            }
            
            // Store response headers
            _responseHeaders = http.responseHeaders;
        };
        
        // Execute request
        try {
            if (_method == "POST" && _postData != null) {
                http.setPostData(_postData);
                http.request(true);
            } else {
                http.request(false);
            }
        } catch (e:Dynamic) {
            _hasErrors = true;
            for (f in _onStdErr) f(this, 'Exception: ${e}');
            _finalizeExecution(1);
        }
    }
    
    /**
     * Execute binary HTTP request
     */
    private function _executeBinaryRequest():Void {
        var request = new openfl.net.URLRequest(_url);
        
        // Set method
        if (_method == "POST") {
            request.method = openfl.net.URLRequestMethod.POST;
            if (_postData != null) {
                request.data = _postData;
            }
        }
        
        // Set headers
        var headers:Array<openfl.net.URLRequestHeader> = [];
        for (key in _headers.keys()) {
            headers.push(new openfl.net.URLRequestHeader(key, _headers.get(key)));
        }
        request.requestHeaders = headers;
        
        // Create loader
        var loader = new openfl.net.URLLoader();
        loader.dataFormat = openfl.net.URLLoaderDataFormat.BINARY;
        
        // Set up event listeners
        loader.addEventListener(openfl.events.Event.COMPLETE, function(e) {
            _responseData = loader.data;
            
            // Clean up
            loader.removeEventListener(openfl.events.Event.COMPLETE, function(e) {});
            loader.removeEventListener(openfl.events.ProgressEvent.PROGRESS, function(e) {});
            loader.removeEventListener(openfl.events.IOErrorEvent.IO_ERROR, function(e) {});
            
            _finalizeExecution(0);
        });
        
        loader.addEventListener(openfl.events.ProgressEvent.PROGRESS, function(e:openfl.events.ProgressEvent) {
            _bytesLoaded = Std.int(e.bytesLoaded);
            _bytesTotal = Std.int(e.bytesTotal);
            
            // Calculate progress
            var progress:Float = 0;
            if (_bytesTotal > 0) {
                progress = _bytesLoaded / _bytesTotal;
            }
            
            // Trigger progress callbacks
            for (f in _onProgress) f(this, progress);
        });
        
        loader.addEventListener(openfl.events.IOErrorEvent.IO_ERROR, function(e:openfl.events.IOErrorEvent) {
            _hasErrors = true;
            for (f in _onStdErr) f(this, e.text);
            
            // Clean up
            loader.removeEventListener(openfl.events.Event.COMPLETE, function(e) {});
            loader.removeEventListener(openfl.events.ProgressEvent.PROGRESS, function(e) {});
            loader.removeEventListener(openfl.events.IOErrorEvent.IO_ERROR, function(e) {});
            
            _finalizeExecution(1);
        });
        
        // Execute request
        try {
            loader.load(request);
        } catch (e:Dynamic) {
            _hasErrors = true;
            for (f in _onStdErr) f(this, 'Exception: ${e}');
            _finalizeExecution(1);
        }
    }
    
    /**
     * Handle HTTP redirects
     */
    private function _handleRedirect(headers:Map<String, String>):Void {
        // Find the Location header
        var location:String = null;
        for (header in headers.keys()) {
            if (header.toLowerCase() == "location") {
                location = headers.get(header);
                break;
            }
        }
        
        if (location == null) {
            _hasErrors = true;
            for (f in _onStdErr) f(this, "No Location header in redirect response");
            _finalizeExecution(1);
            return;
        }
        
        // Increment redirect count and check limits
        _redirectCount++;
        if (_redirectCount > 5) {
            _hasErrors = true;
            for (f in _onStdErr) f(this, "Too many redirects");
            _finalizeExecution(1);
            return;
        }
        
        // Create a new executor to follow the redirect
        var redirectExecutor = new NetworkExecutor(location, _method, _headers, _postData, _binary);
        redirectExecutor._followRedirect = true;
        redirectExecutor._redirectCount = _redirectCount;
        
        // Connect callbacks
        redirectExecutor.onStdOut.add(function(executor, data) {
            for (f in _onStdOut) f(this, data);
        });
        
        redirectExecutor.onStdErr.add(function(executor, error) {
            for (f in _onStdErr) f(this, error);
        });
        
        redirectExecutor.onProgress.add(function(executor, progress) {
            for (f in _onProgress) f(this, progress);
        });
        
        redirectExecutor.onStop.add(function(executor) {
            // Copy data from redirect executor - need to cast to access subclass fields
            var networkExecutor:NetworkExecutor = cast executor;
            _responseData = networkExecutor._responseData; // Access private field directly in this case
            _responseHeaders = networkExecutor._responseHeaders; // Access private field directly in this case
            _hasErrors = executor.hasErrors;
            _exitCode = executor.exitCode;
            
            // Finalize this executor
            _finalizeExecution(_exitCode);
        });
        
        // Execute the redirect
        redirectExecutor.execute();
    }
    
    /**
     * Finalize execution
     */
    private function _finalizeExecution(exitCode:Float):Void {
        _exitCode = exitCode;
        _running = false;
        _stopTime = Sys.time();
        
        // Send standard output with the response data
        var dataStr = _responseData != null ? (_responseData is String ? _responseData : "[Binary Data]") : "[No Data]";
        for (f in _onStdOut) f(this, dataStr);
        
        // Trigger stop callbacks
        for (f in _onStop) f(this);
    }
    
    /**
     * Simulate stopping the executor
     */
    public function simulateStop():Void {
        if (_running) {
            _running = false;
            _stopTime = Sys.time();
            _exitCode = 0;
            for (f in _onStop) f(this);
        }
    }
    
    /**
     * Stop the executor
     */
    public function stop(?forced:Bool):Void {
        // Cannot actually stop an HTTP request in progress
        // Just simulate the stop
        simulateStop();
    }
    
    /**
     * Kill the executor
     */
    public function kill(signal:champaign.sys.io.process.ProcessTools.KillSignal):Void {
        // Cannot kill an HTTP request
        // Just simulate the stop
        simulateStop();
    }
}

/**
 * HCLDownloader handles the downloading of files from the HCL portal
 * using authentication tokens stored in SuperHumanSecrets.
 */
class HCLDownloader {

    // Singleton instance
    static var _instance:HCLDownloader;
    
    /**
     * Update the current step and report progress
     * @param step The new download step
     * @param subProgress Optional progress within the step (0-1)
     */
    private function updateStep(step:HCLDownloadStep, ?subProgress:Float = 1.0):Void {
        _currentStep = step;
        reportProgress(subProgress);
    }
    
    /**
     * Report progress based on current step and sub-progress
     * @param subProgress Optional progress within the current step (0-1)
     */
    private function reportProgress(?subProgress:Float = 1.0):Void {
        if (_currentFile == null) return;
        
        var percentage = ProgressRangeMap.calculateProgress(_currentStep, subProgress);
        for (f in _onDownloadProgress) f(this, _currentFile, percentage / 100);
    }

    // Constants for URL and endpoints
    private static final MYHCL_PORTAL_URL:String = "https://my.hcltechsw.com";
    private static final MYHCL_API_URL:String = "https://api.hcltechsw.com";
    private static final MYHCL_TOKEN_URL:String = "https://api.hcltechsw.com/v1/apitokens/exchange";
    private static final MYHCL_CATALOG_URL:String = "https://my.hcltechsw.com/files/domino";
    private static final MYHCL_DOWNLOAD_URL_PREFIX:String = "https://api.hcltechsw.com/v1/files/";
    private static final MYHCL_DOWNLOAD_URL_SUFFIX:String = "/download";

    // Event handlers
    var _onDownloadStart:ChainedList<(HCLDownloader, SuperHumanCachedFile)->Void, HCLDownloader>;
    var _onDownloadProgress:ChainedList<(HCLDownloader, SuperHumanCachedFile, Float)->Void, HCLDownloader>;
    var _onDownloadComplete:ChainedList<(HCLDownloader, SuperHumanCachedFile, Bool)->Void, HCLDownloader>;
    var _onDownloadError:ChainedList<(HCLDownloader, SuperHumanCachedFile, String)->Void, HCLDownloader>;

    // Current file being downloaded
    var _currentFile:SuperHumanCachedFile;
    
    // Access token for HCL downloads
    var _accessToken:String;
    
    // Temp file paths
    var _tempFilePath:String;
    
    // URL loaders
    var _tokenLoader:URLLoader;
    var _downloadUrlLoader:URLLoader;
    var _downloadLoader:URLLoader;
    
    // Download URL
    var _downloadUrl:String;
    
    // Is a download in progress
    var _isDownloading:Bool = false;
    
    // Current token being used
    var _currentToken:String;
    
    // Current token name being used
    var _currentTokenName:String;
    
    /**
     * Save the configuration to persist token changes
     * This calls into SuperHumanInstaller to save the entire config
     */
    private function _saveConfig():Void {
        try {
            // Get the SuperHumanInstaller instance
            var installer = SuperHumanInstaller.getInstance();
            
            // Cast to Dynamic to allow calling internal methods if available
            var dynamicInstaller:Dynamic = installer;
            
            // Check if installer has a public saveConfig method
            if (Reflect.hasField(installer, "saveConfig") && Reflect.isFunction(Reflect.field(installer, "saveConfig"))) {
                // Call the public saveConfig method if it exists
                Reflect.callMethod(installer, Reflect.field(installer, "saveConfig"), []);
                Logger.debug('HCLDownloader: Called public saveConfig method');
                return;
            }
            
            // Try to trigger saving through other means - dispatch an event
            var saveEvent = new superhuman.events.SuperHumanApplicationEvent(
                superhuman.events.SuperHumanApplicationEvent.SAVE_APP_CONFIGURATION);
            Lib.current.dispatchEvent(saveEvent);
            Logger.debug('HCLDownloader: Dispatched SAVE_APP_CONFIGURATION event');
        } catch (e:Dynamic) {
            Logger.error('HCLDownloader: Failed to save config: ${e}');
        }
    }
    
    /**
     * Update an HCL token in secrets
     * @param tokenName The name of the token to update
     * @param newToken The new token value
     */
    private function updateHCLToken(tokenName:String, newToken:String):Void {
        var secrets = SuperHumanInstaller.getInstance().config.secrets;
        if (secrets == null || secrets.hcl_download_portal_api_keys == null) {
            Logger.error('HCLDownloader: Cannot update token - no secrets found');
            return;
        }
        
        var keys:Array<Dynamic> = cast(secrets.hcl_download_portal_api_keys, Array<Dynamic>);
        for (i in 0...keys.length) {
            var key = keys[i];
            if (Reflect.field(key, "name") == tokenName) {
                // Update the token
                Reflect.setField(key, "key", newToken);
                
                // Save the entire configuration to persist token changes
                // We can't call save() directly on secrets since it's just a typedef
                _saveConfig();
                
                Logger.info('HCLDownloader: Updated token [${tokenName}] with new rotated value');
                return;
            }
        }
        
        Logger.error('HCLDownloader: Could not find token [${tokenName}] to update');
    }
    
    // Current download step
    var _currentStep:HCLDownloadStep = HCLDownloadStep.None;
    
    /**
     * Get the singleton instance
     */
    public static function getInstance():HCLDownloader {
        if (_instance == null) _instance = new HCLDownloader();
        return _instance;
    }

    /**
     * Event triggered when download starts
     */
    public var onDownloadStart(get, never):ChainedList<(HCLDownloader, SuperHumanCachedFile)->Void, HCLDownloader>;
    function get_onDownloadStart() return _onDownloadStart;

    /**
     * Event triggered during download progress
     */
    public var onDownloadProgress(get, never):ChainedList<(HCLDownloader, SuperHumanCachedFile, Float)->Void, HCLDownloader>;
    function get_onDownloadProgress() return _onDownloadProgress;

    /**
     * Event triggered when download completes
     */
    public var onDownloadComplete(get, never):ChainedList<(HCLDownloader, SuperHumanCachedFile, Bool)->Void, HCLDownloader>;
    function get_onDownloadComplete() return _onDownloadComplete;

    /**
     * Event triggered on download error
     */
    public var onDownloadError(get, never):ChainedList<(HCLDownloader, SuperHumanCachedFile, String)->Void, HCLDownloader>;
    function get_onDownloadError() return _onDownloadError;

    /**
     * Current file being downloaded
     */
    public var currentFile(get, never):SuperHumanCachedFile;
    function get_currentFile() return _currentFile;
    
    /**
     * Current step in the download process
     */
    public var currentStep(get, never):HCLDownloadStep;
    function get_currentStep() return _currentStep;
    
    /**
     * Private constructor for singleton pattern
     */
    function new() {
        _onDownloadStart = new ChainedList(this);
        _onDownloadProgress = new ChainedList(this);
        _onDownloadComplete = new ChainedList(this);
        _onDownloadError = new ChainedList(this);
    }
    
    /**
     * Get HCL token from secrets
     */
    private function getHCLToken(tokenName:String):String {
        var secrets = SuperHumanInstaller.getInstance().config.secrets;
        if (secrets == null || secrets.hcl_download_portal_api_keys == null) return null;
        
        var keys:Array<Dynamic> = cast(secrets.hcl_download_portal_api_keys, Array<Dynamic>);
        for (i in 0...keys.length) {
            var key = keys[i];
            if (Reflect.field(key, "name") == tokenName) {
                return Reflect.field(key, "key");
            }
        }
        
        return null;
    }

    /**
     * Download a file from HCL Portal using a token
     * @param file The cached file to download
     * @param tokenName The name of the token to use
     */
    public function downloadFileWithHCLToken(file:SuperHumanCachedFile, tokenName:String):Void {
        // Store current file
        _currentFile = file;
        
        // Get token from secrets
        var token = getHCLToken(tokenName);
        if (token == null) {
            triggerError("Invalid token: " + tokenName);
            return;
        }
        
        // Store the token and token name
        _currentToken = token;
        _currentTokenName = tokenName;
        
        // Notify download is starting
        for (f in _onDownloadStart) f(this, file);
        
        // Create temp file path
        var cacheDir = SuperHumanFileCache.getCacheDirectory();
        _tempFilePath = cacheDir + "/" + file.originalFilename + ".download";
        
        // Start the download process by getting access token
        getAccessToken(token);
    }

    /**
     * Get list of available HCL tokens
     */
    public function getAvailableHCLTokens():Array<{name:String, key:String}> {
        var result:Array<{name:String, key:String}> = [];
        var secrets = SuperHumanInstaller.getInstance().config.secrets;
        
        if (secrets == null || secrets.hcl_download_portal_api_keys == null) return result;
        
        var keys:Array<Dynamic> = cast(secrets.hcl_download_portal_api_keys, Array<Dynamic>);
        for (i in 0...keys.length) {
            var key = keys[i];
            result.push({
                name: Reflect.field(key, "name"), 
                key: Reflect.field(key, "key")
            });
        }
        
        return result;
    }

    /**
     * Get list of available custom resource URLs
     */
    public function getAvailableCustomResources():Array<{name:String, url:String}> {
        var result:Array<{name:String, url:String}> = [];
        var secrets = SuperHumanInstaller.getInstance().config.secrets;
        
        if (secrets == null || secrets.custom_resource_url == null) return result;
        
        var resources:Array<Dynamic> = cast(secrets.custom_resource_url, Array<Dynamic>);
        for (i in 0...resources.length) {
            var resource = resources[i];
            result.push({
                name: Reflect.field(resource, "name"), 
                url: Reflect.field(resource, "url")
            });
        }
        
        return result;
    }

    /**
     * Step 1: Get access token from refresh token
     * @param refreshToken The refresh token to use
     */
    private function getAccessToken(refreshToken:String):Void {
        if (_isDownloading) {
            Logger.warning('HCLDownloader: Already downloading a file');
            return;
        }
        
        // Update current step
        _currentStep = HCLDownloadStep.GettingAccessToken;
        
        // Always get a fresh token - never use cached token
        _accessToken = null;
        
        // Note: Previously we would check for a cached token file and use it if available
        // This was causing 403 errors, so now we always get a fresh token
        
        Logger.info('HCLDownloader: Getting access token from refresh token');
        Logger.debug('HCLDownloader: Token length: ${refreshToken != null ? refreshToken.length : 0}');
        
        // Store token for potential retry
        _currentToken = refreshToken;
        
        // Use Haxe standard library Http instead of URLLoader for better compatibility
        var http = new haxe.Http(MYHCL_TOKEN_URL);
        
        // Match headers from working curl command
        http.setHeader("Content-Type", "application/json");
        http.setHeader("Accept", "application/json");
        http.setHeader("User-Agent", "curl/7.68.0"); // Mimic curl's user agent
        
        // Add callbacks to process the response
        http.onData = function(data:String) {
            Logger.debug('HCLDownloader: Received token response: ${data}');
            
            // Save response to a file for debugging
            try {
                sys.io.File.saveContent("token_request.json", data);
                Logger.debug('HCLDownloader: Saved token response to token_request.json');
            } catch (e:Dynamic) {
                Logger.error('HCLDownloader: Failed to save token response to file: ${e}');
            }
            
            // Process response - similar to _accessTokenLoaderComplete
            var responseJson:Dynamic;
            try {
                responseJson = haxe.Json.parse(data);
                Logger.debug('HCLDownloader: Parsed JSON response successfully');
            } catch (e:Dynamic) {
                triggerError('Failed to parse token response: ${e}: ${data}');
                return;
            }
            
            // Extract refresh token first - this is CRITICAL as the refresh token is rotated on each use
            var newRefreshToken:String = null;
            if (Reflect.hasField(responseJson, "refreshToken")) {
                newRefreshToken = Reflect.field(responseJson, "refreshToken");
                Logger.debug('HCLDownloader: Found new rotated refresh token in response');
                
                // Save the new refresh token back to SuperHumanSecrets
                if (newRefreshToken != null && newRefreshToken != refreshToken) {
                    updateHCLToken(_currentTokenName, newRefreshToken);
                    Logger.info('HCLDownloader: Updated rotated refresh token in secrets');
                }
            }
            
            // Extract access token - standard OAuth responses use "access_token" field
            var accessToken:String = null;
            
            // Try standard OAuth field first
            if (Reflect.hasField(responseJson, "access_token")) {
                accessToken = Reflect.field(responseJson, "access_token");
                Logger.debug('HCLDownloader: Found access_token field in response');
            } 
            // Try HCL specific field if standard not found
            else if (Reflect.hasField(responseJson, "accessToken")) {
                accessToken = Reflect.field(responseJson, "accessToken");
                Logger.debug('HCLDownloader: Found accessToken field in response');
            }
            
            if (accessToken == null) {
                var errorMessage = "Unknown error";
                if (Reflect.hasField(responseJson, "error")) {
                    errorMessage = Reflect.field(responseJson, "error");
                    if (Reflect.hasField(responseJson, "error_description")) {
                        errorMessage += ": " + Reflect.field(responseJson, "error_description");
                    }
                } else if (Reflect.hasField(responseJson, "summary")) {
                    errorMessage = Reflect.field(responseJson, "summary");
                }
                
                // Log the full response for debugging
                Logger.error('HCLDownloader: Full response: ${data}');
                triggerError('Failed to get access token: ${errorMessage}');
                return;
            }
            
        Logger.info('HCLDownloader: Successfully obtained fresh access token');
        _accessToken = accessToken;
        _isDownloading = true;
        
        // Continue to next step - first get catalog to find file ID
        fetchCatalog();
        };
        
        http.onError = function(error:String) {
            Logger.error('HCLDownloader: Token request failed with error: ${error}');
            triggerError('Failed to get access token: ${error}');
        };
        
        http.onStatus = function(status:Int) {
            Logger.debug('HCLDownloader: HTTP status code: ${status}');
        };
        
        // Format data as JSON exactly as in the bash script
        var payload = { refreshToken: refreshToken };
        var jsonPayload = haxe.Json.stringify(payload);
        Logger.debug('HCLDownloader: Full request data: ${jsonPayload}');
        
        // Save request to a file for debugging
        try {
            sys.io.File.saveContent("token_request.json", jsonPayload);
            Logger.debug('HCLDownloader: Saved token request payload to token_request.json');
        } catch (e:Dynamic) {
            Logger.error('HCLDownloader: Failed to save token request to file: ${e}');
        }
        
        // Send the request
        try {
            Logger.debug('HCLDownloader: Sending token request to ${MYHCL_TOKEN_URL}');
            http.setPostData(jsonPayload);
            http.request(true); // true = POST request
        } catch (e:Dynamic) {
            triggerError('Failed to send token request: ${e}');
        }
    }

    /**
     * Handle access token loader completion
     */
    private function _accessTokenLoaderComplete(e:Event):Void {
        var responseContent:String = _tokenLoader.data;
        Logger.debug('HCLDownloader: Received token response: ${responseContent}');
        
        // Save response to a file for debugging
        try {
            sys.io.File.saveContent("token_request.json", responseContent);
            Logger.debug('HCLDownloader: Saved token response to token_request.json');
        } catch (e:Dynamic) {
            Logger.error('HCLDownloader: Failed to save token response to file: ${e}');
        }
        
        // Clean up loader
        _cleanupTokenLoader();
        
        // Parse JSON
        var responseJson:Dynamic;
        try {
            responseJson = haxe.Json.parse(responseContent);
            Logger.debug('HCLDownloader: Parsed JSON response successfully');
        } catch (e:Dynamic) {
            triggerError('Failed to parse token response: ${e}: ${responseContent}');
            return;
        }
        
        // Extract access token - standard OAuth responses use "access_token" field
        var accessToken:String = null;
        
        // Try standard OAuth field first
        if (Reflect.hasField(responseJson, "access_token")) {
            accessToken = Reflect.field(responseJson, "access_token");
            Logger.debug('HCLDownloader: Found access_token field in response');
        } 
        // Try HCL specific field if standard not found
        else if (Reflect.hasField(responseJson, "accessToken")) {
            accessToken = Reflect.field(responseJson, "accessToken");
            Logger.debug('HCLDownloader: Found accessToken field in response');
        }
        
        if (accessToken == null) {
            var errorMessage = "Unknown error";
            if (Reflect.hasField(responseJson, "error")) {
                errorMessage = Reflect.field(responseJson, "error");
                if (Reflect.hasField(responseJson, "error_description")) {
                    errorMessage += ": " + Reflect.field(responseJson, "error_description");
                }
            } else if (Reflect.hasField(responseJson, "summary")) {
                errorMessage = Reflect.field(responseJson, "summary");
            }
            
            // Log the full response for debugging
            Logger.error('HCLDownloader: Full response: ${responseContent}');
            triggerError('Failed to get access token: ${errorMessage}');
            return;
        }
        
        Logger.info('HCLDownloader: Successfully obtained fresh access token');
        _accessToken = accessToken;
        
        // Continue to next step - first look up file ID in catalog
        fetchCatalog();
    }
    
    /**
     * Handle access token loader error
     */
    private function _accessTokenLoaderError(e:IOErrorEvent):Void {
        _cleanupTokenLoader();
        Logger.error('HCLDownloader: Token request failed with error: ${e.text}');
        Logger.error('HCLDownloader: Error ID: ${e.errorID}');
        
        // Log all error fields for maximum diagnostic information
        var errorDetails = "";
        for (field in Reflect.fields(e)) {
            try {
                var value = Reflect.field(e, field);
                if (value != null && field != "target") {
                    errorDetails += field + ": " + value + ", ";
                }
            } catch (_) {}
        }
        
        if (errorDetails.length > 0) {
            Logger.error('HCLDownloader: Error details: ${errorDetails}');
        }
        
        triggerError('Failed to get access token: ${e.text}');
    }
    
    /**
     * Clean up token loader resources
     */
    private function _cleanupTokenLoader():Void {
        if (_tokenLoader != null) {
            _tokenLoader.removeEventListener(Event.COMPLETE, _accessTokenLoaderComplete);
            _tokenLoader.removeEventListener(IOErrorEvent.IO_ERROR, _accessTokenLoaderError);
            _tokenLoader.removeEventListener(Event.OPEN, function(e) {});
            _tokenLoader.removeEventListener(ProgressEvent.PROGRESS, function(e) {});
            _tokenLoader = null;
        }
    }

    /**
     * Step 2: Get download URL for the file
     */
    /**
     * Fetch the file catalog to get correct file IDs
     */
    private function fetchCatalog():Void {
        // Update current step
        _currentStep = HCLDownloadStep.FetchingCatalog;
        
        Logger.info('HCLDownloader: Fetching file catalog');
        
        // Use Haxe Http for consistency
        var http = new haxe.Http(MYHCL_CATALOG_URL);
        
        // Add authorization header with bearer token
        http.setHeader("Authorization", "Bearer " + _accessToken);
        http.setHeader("Accept", "application/json");
        http.setHeader("User-Agent", "curl/7.68.0"); // Mimic curl's user agent
        
        // Add callback for successful response
        http.onData = function(data:String) {
            Logger.debug('HCLDownloader: Received catalog response');
            
            // Save response to a file for debugging
            try {
                sys.io.File.saveContent("catalog_response.json", data);
                Logger.debug('HCLDownloader: Saved catalog response to catalog_response.json');
            } catch (e:Dynamic) {
                Logger.error('HCLDownloader: Failed to save catalog response to file: ${e}');
            }
            
            // Parse JSON
            var catalogJson:Dynamic;
            try {
                catalogJson = haxe.Json.parse(data);
                Logger.debug('HCLDownloader: Parsed catalog JSON successfully');
            } catch (e:Dynamic) {
                triggerError('Failed to parse catalog: ${e}');
                return;
            }
            
            // Find the file ID by name
            var fileId = findFileIdByName(catalogJson, _currentFile.originalFilename);
            if (fileId != null) {
                Logger.info('HCLDownloader: Found file ID in catalog: ${fileId}');
                // Store file ID in hash field
                _currentFile.hash = fileId;
                getDownloadUrl();
            } else {
                triggerError('Failed to find file ID for ${_currentFile.originalFilename} in catalog');
            }
        };
        
        // Add callback for error
        http.onError = function(error:String) {
            Logger.error('HCLDownloader: Catalog request failed with error: ${error}');
            triggerError('Failed to fetch catalog: ${error}');
        };
        
        // Send the request
        try {
            Logger.debug('HCLDownloader: Sending catalog request to ${MYHCL_CATALOG_URL}');
            http.request(false); // false = GET request
        } catch (e:Dynamic) {
            Logger.error('HCLDownloader: Failed to send catalog request: ${e}');
            triggerError('Failed to send catalog request: ${e}');
        }
    }
    
    /**
     * Find a file ID in the catalog by file name
     * @param catalog The catalog JSON
     * @param fileName The file name to look for
     * @return The file ID if found, null otherwise
     */
    private function findFileIdByName(catalog:Dynamic, fileName:String):String {
        // Update current step
        _currentStep = HCLDownloadStep.FindingFile;
        
        Logger.debug('HCLDownloader: Searching for ${fileName} in catalog');
        
        var items:Array<Dynamic>;
        
        // Handle different possible catalog formats
        if (Std.is(catalog, Array)) {
            // Catalog is an array directly
            items = cast(catalog, Array<Dynamic>);
            Logger.debug('HCLDownloader: Catalog is a direct array with ${items.length} items');
        } else if (Reflect.hasField(catalog, "items") && Std.is(catalog.items, Array)) {
            // Catalog has an items field that's an array
            items = cast(catalog.items, Array<Dynamic>);
            Logger.debug('HCLDownloader: Catalog has an items array with ${items.length} items');
        } else if (Reflect.hasField(catalog, "files") && Std.is(catalog.files, Array)) {
            // Catalog has a files field that's an array (HCL format)
            items = cast(catalog.files, Array<Dynamic>);
            Logger.debug('HCLDownloader: Catalog has a files array with ${items.length} items');
        } else {
            // Try to iterate through the object's fields as a last resort
            items = [];
            var fields = Reflect.fields(catalog);
            for (field in fields) {
                var value = Reflect.field(catalog, field);
                if (Std.is(value, Array)) {
                    // Found an array field, check if it contains items with name and id
                    var arrayValue:Array<Dynamic> = cast value;
                    if (arrayValue.length > 0 && 
                        Std.is(arrayValue[0], Dynamic) && 
                        Reflect.hasField(arrayValue[0], "name") &&
                        Reflect.hasField(arrayValue[0], "id")) {
                        items = arrayValue;
                        Logger.debug('HCLDownloader: Found array field "${field}" with ${items.length} catalog items');
                        break;
                    }
                }
                else if (Std.is(value, Dynamic) && Reflect.hasField(value, "name") && Reflect.hasField(value, "id")) {
                    items.push(value);
                }
            }
            
            if (items.length > 0) {
                Logger.debug('HCLDownloader: Extracted ${items.length} items from catalog object fields');
            } else {
                Logger.error('HCLDownloader: Invalid catalog format - could not extract items');
                return null;
            }
        }
        
        // First, try exact match
        for (item in items) {
            if (Reflect.hasField(item, "name") && Reflect.hasField(item, "id")) {
                var itemName:String = Reflect.field(item, "name");
                if (itemName == fileName) {
                    Logger.debug('HCLDownloader: Found exact match for ${fileName}');
                    
                    // Extract SHA256 hash if available (for catalog verification later)
                    if (Reflect.hasField(item, "checksums") && 
                        Reflect.hasField(Reflect.field(item, "checksums"), "sha256")) {
                        var checksums = Reflect.field(item, "checksums");
                        var sha256 = Reflect.field(checksums, "sha256");
                        Logger.debug('HCLDownloader: Found SHA256 hash: ${sha256}');
                        _currentFile.sha256 = sha256;
                    }
                    
                    return Reflect.field(item, "id");
                }
            }
        }
        
        // Next, try case-insensitive match
        var lowerFileName = fileName.toLowerCase();
        for (item in items) {
            if (Reflect.hasField(item, "name") && Reflect.hasField(item, "id")) {
                var itemName:String = Reflect.field(item, "name");
                if (itemName.toLowerCase() == lowerFileName) {
                    Logger.debug('HCLDownloader: Found case-insensitive match for ${fileName}');
                    return Reflect.field(item, "id");
                }
            }
        }
        
        // Finally, try partial match (if filename is contained in the item name)
        for (item in items) {
            if (Reflect.hasField(item, "name") && Reflect.hasField(item, "id")) {
                var itemName:String = Reflect.field(item, "name");
                if (itemName.toLowerCase().indexOf(lowerFileName) >= 0) {
                    Logger.debug('HCLDownloader: Found partial match for ${fileName} in ${itemName}');
                    return Reflect.field(item, "id");
                }
            }
        }
        
        // No match found
        Logger.error('HCLDownloader: No match found for ${fileName} in catalog');
        return null;
    }
    
    // Flag to indicate if we're in the process of following redirects
    var _followingRedirects:Bool = false;
    
    // Store the final URL we found after redirects
    var _finalRedirectUrl:String = null;
    
    /**
     * Step 2: Get download URL for the file
     */
    private function getDownloadUrl():Void {
        // Update current step
        _currentStep = HCLDownloadStep.GettingDownloadURL;
        
        Logger.info('HCLDownloader: Getting download URL for file ID: ${_currentFile.hash}');
        
        // Reset redirect tracking
        _followingRedirects = false;
        _finalRedirectUrl = null;
        
        // Construct the download URL using the file ID
        var downloadUrl = MYHCL_DOWNLOAD_URL_PREFIX + _currentFile.hash + MYHCL_DOWNLOAD_URL_SUFFIX;
        Logger.debug('HCLDownloader: Requesting download URL from: ${downloadUrl}');
        
        // Start following redirects from this URL
        _followingRedirects = true;
        getUrlWithRedirects(downloadUrl);
    }
    
    /**
     * Follow HTTP redirects to get the final download URL
     * This is a non-recursive implementation that handles one redirect at a time
     * @param url The URL to request
     */
    private function getUrlWithRedirects(url:String):Void {
        var maxRedirects = 5;
        var redirectCount = 0;
        var currentUrl = url;
        
        // Create a function that can be called to process the current URL
        function processUrl():Void {
            if (redirectCount > maxRedirects) {
                Logger.error('HCLDownloader: Too many redirects (${redirectCount})');
                triggerError('Failed to get download URL: Too many redirects');
                _followingRedirects = false;
                return;
            }
            
            if (!_followingRedirects) {
                // We've already processed a redirect that led to a download
                Logger.debug('HCLDownloader: Redirect chain was interrupted, ignoring further processing');
                return;
            }
            
            var http = new haxe.Http(currentUrl);
            
            // Add authorization header with bearer token
            http.setHeader("Authorization", "Bearer " + _accessToken);
            http.setHeader("Accept", "application/json");
            http.setHeader("User-Agent", "curl/7.68.0"); // Mimic curl's user agent
            
            http.onData = function(data:String) {
                if (!_followingRedirects) return; // Chain was already completed
                
                Logger.debug('HCLDownloader: Received response from URL: ${currentUrl}');
                
                // Save response to a file for debugging
                if (redirectCount == 0) { // Only save the first response
                    try {
                        sys.io.File.saveContent("download_url_response.json", data);
                        Logger.debug('HCLDownloader: Saved download URL response to download_url_response.json');
                    } catch (e:Dynamic) {
                        Logger.error('HCLDownloader: Failed to save download URL response to file: ${e}');
                    }
                }
                
                // Check if this is an error response
                try {
                    var responseJson = haxe.Json.parse(data);
                    
                    // If we got valid JSON, it's likely an error message
                    if (Reflect.hasField(responseJson, "summary")) {
                        _followingRedirects = false;
                        triggerError('Failed to get download URL: ${responseJson.summary}');
                        return;
                    }
                } catch (e:Dynamic) {
                    // Not JSON, might be text or binary data - continue
                }
                
                // If we get actual data and no more redirects, use the response
                var trimmedData = StringTools.trim(data);
                if (trimmedData.length > 0 && StringTools.startsWith(trimmedData.toLowerCase(), "http")) {
                    // Response contains a URL
                    _finalRedirectUrl = trimmedData;
                    Logger.debug('HCLDownloader: Got download URL from response: ${_finalRedirectUrl}');
                    startDownload();
                    return;
                }
                
                // If we got here, but the response is empty or not a URL,
                // assume the current URL is the final one
                _finalRedirectUrl = currentUrl;
                Logger.debug('HCLDownloader: Using current URL as download URL: ${_finalRedirectUrl}');
                startDownload();
            };

            http.onStatus = function(status:Int) {
                Logger.debug('HCLDownloader: HTTP Status for ${currentUrl}: ${status}');
                
                if (!_followingRedirects) return; // Chain was already completed
                
                if (status >= 300 && status < 400) {
                    // Get the Location header for redirects
                    var headers = http.responseHeaders;
                    var location = null;
                    
                    // Find the Location header (case-insensitive)
                    for (header in headers.keys()) {
                        if (header.toLowerCase() == "location") {
                            location = headers.get(header);
                            break;
                        }
                    }
                    
                    if (location != null) {
                        Logger.debug('HCLDownloader: Redirecting to: ${location}');
                        // Update for next redirect
                        currentUrl = location;
                        redirectCount++;
                        processUrl(); // Process the next URL in the chain
                    } else {
                        Logger.error('HCLDownloader: No Location header found for redirect status ${status}');
                        _followingRedirects = false;
                        triggerError('Failed to get download URL: No Location header in redirect response');
                    }
                }
                // No special cases for other status codes like 403 - we MUST follow the redirects
            };

            http.onError = function(error:String) {
                if (!_followingRedirects) return; // Chain was already completed
                
                Logger.error('HCLDownloader: Error requesting ${currentUrl}: ${error}');
                
                // Always treat errors as fatal - no fallbacks
                _followingRedirects = false;
                triggerError('Failed to get download URL: ${error}');
            };

            try {
                Logger.debug('HCLDownloader: Making request to ${currentUrl} (redirect #${redirectCount})');
                http.request(false); // false = GET request
            } catch (e:Dynamic) {
                Logger.error('HCLDownloader: Exception making request to ${currentUrl}: ${e}');
                _followingRedirects = false;
                triggerError('Failed to send download URL request: ${e}');
            }
        }
        
        // Start the chain
        processUrl();
    }
    
    /**
     * Start the actual file download after redirect resolution
     */
    private function startDownload():Void {
        if (!_followingRedirects) return; // Another download already started
        
        // Mark as no longer following redirects to avoid multiple downloads
        _followingRedirects = false;
        
        // Set the download URL and start the download
        _downloadUrl = _finalRedirectUrl;
        downloadFile();
    }

    // URL stream for file downloading
    private var _urlStream:URLStream;
    
    // File output for writing downloaded data
    private var _fileOutput:sys.io.FileOutput;
    
    // Total bytes for the current download 
    private var _downloadBytesTotal:Int = 0;
    
    /**
     * Step 3: Download the file using URLStream for efficient streaming download
     */
    private function downloadFile():Void {
        // Update current step
        _currentStep = HCLDownloadStep.Downloading;
        
        // Create a temp file path with .download extension (matching domdownload.sh)
        var cacheDir = SuperHumanFileCache.getCacheDirectory();
        _tempFilePath = cacheDir + "/" + _currentFile.originalFilename + ".download";
        
        // Create URL request for file download
        var downloadRequest = new URLRequest(_downloadUrl);
        downloadRequest.requestHeaders = [
            new URLRequestHeader("Authorization", "Bearer " + _accessToken),
            new URLRequestHeader("User-Agent", "curl/7.68.0") // Match curl's user agent
        ];
        
        try {
            // Create and open file output for writing
            try {
                Logger.debug('HCLDownloader: Opening output file: ${_tempFilePath}');
                _fileOutput = sys.io.File.write(_tempFilePath, true);
            } catch (e:Dynamic) {
                triggerError('Failed to open output file: ${e}');
                return;
            }
            
            // Create URLStream for efficient streaming
            _urlStream = new URLStream();
            
            // Set up event listeners
            _urlStream.addEventListener(Event.OPEN, function(e:Event):Void {
                Logger.debug('HCLDownloader: Download connection opened');
            });
            
            _urlStream.addEventListener(ProgressEvent.PROGRESS, function(e:ProgressEvent):Void {
                // Store total bytes for the download
                _downloadBytesTotal = Std.int(e.bytesTotal);
                
                // Calculate progress percentage and notify listeners
                var progress:Float = 0;
                if (e.bytesTotal > 0) {
                    progress = e.bytesLoaded / e.bytesTotal;
                }
                
                Logger.debug('HCLDownloader: Download progress: ${Math.round(progress * 100)}% (${e.bytesLoaded}/${e.bytesTotal} bytes)');
                for (f in _onDownloadProgress) f(this, _currentFile, progress);
                
                // Process available bytes in the stream
                processAvailableBytes();
            });
            
            _urlStream.addEventListener(Event.COMPLETE, function(e:Event):Void {
                Logger.info('HCLDownloader: Download stream complete');
                
                // Update step to writing file now that download is complete
                updateStep(HCLDownloadStep.WritingFile);
                
                // Process any remaining bytes in the stream
                processAvailableBytes();
                
                // Close the output file
                try {
                    if (_fileOutput != null) {
                        _fileOutput.close();
                        _fileOutput = null;
                    }
                } catch (e:Dynamic) {
                    Logger.error('HCLDownloader: Error closing output file: ${e}');
                }
                
                // Clean up stream
                cleanupUrlStream();
                
                // Verify the downloaded file - this will move to the next step
                verifyFileHash();
            });
            
            _urlStream.addEventListener(IOErrorEvent.IO_ERROR, function(e:IOErrorEvent):Void {
                Logger.error('HCLDownloader: Download error: ${e.text}, ID: ${e.errorID}');
                
                // Log all error fields for maximum diagnostic information
                var errorDetails = "";
                for (field in Reflect.fields(e)) {
                    try {
                        var value = Reflect.field(e, field);
                        if (value != null && field != "target") {
                            errorDetails += field + ": " + value + ", ";
                        }
                    } catch (_) {}
                }
                
                if (errorDetails.length > 0) {
                    Logger.error('HCLDownloader: Error details: ${errorDetails}');
                }
                
                // Close the output file
                try {
                    if (_fileOutput != null) {
                        _fileOutput.close();
                        _fileOutput = null;
                    }
                } catch (e:Dynamic) {
                    Logger.error('HCLDownloader: Error closing output file: ${e}');
                }
                
                cleanupUrlStream();
                triggerError('Failed to download file: ${e.text}');
            });
            
            // Start the download
            Logger.debug('HCLDownloader: Starting file download from ${_downloadUrl}');
            _urlStream.load(downloadRequest);
            
        } catch (e:Dynamic) {
            // Close the output file if needed
            try {
                if (_fileOutput != null) {
                    _fileOutput.close();
                    _fileOutput = null;
                }
            } catch (_) {}
            
            cleanupUrlStream();
            triggerError('Failed to start file download: ${e}');
        }
    }
    
    /**
     * Process bytes available in the URL stream
     * This is called during progress events and on completion
     */
    private function processAvailableBytes():Void {
        if (_urlStream == null || _fileOutput == null) return;
        
        try {
            // Process data as it arrives in the stream
            while (_urlStream.bytesAvailable > 0) {
                // Read from stream in chunks (10MB at a time)
                var chunkSize = Std.int(Math.min(10485760, _urlStream.bytesAvailable));
                var buffer = new ByteArray();
                
                // Read data from the stream into our buffer
                _urlStream.readBytes(buffer, 0, chunkSize);
                
                // Write the buffer to the file directly
                for (i in 0...chunkSize) {
                    _fileOutput.writeByte(buffer[i]);
                }
            }
        } catch (e:Dynamic) {
            Logger.error('HCLDownloader: Error processing stream data: ${e}');
            // Don't close file or cleanup here - let the error event handler do that
        }
    }
    
    /**
     * Clean up URL stream resources
     */
    private function cleanupUrlStream():Void {
        if (_urlStream != null) {
            try {
                _urlStream.close(); // Close the stream if it's open
            } catch (e:Dynamic) {
                Logger.error('HCLDownloader: Error closing URL stream: ${e}');
            }
            
            // Remove all event listeners
            _urlStream.removeEventListener(Event.OPEN, function(e) {});
            _urlStream.removeEventListener(ProgressEvent.PROGRESS, function(e) {});
            _urlStream.removeEventListener(Event.COMPLETE, function(e) {});
            _urlStream.removeEventListener(IOErrorEvent.IO_ERROR, function(e) {});
            
            _urlStream = null;
        }
    }

    /**
     * Step 4: Verify the file hash
     */
    private function verifyFileHash():Void {
        // Update current step
        _currentStep = HCLDownloadStep.VerifyingHash;
        
        Logger.info('HCLDownloader: Verifying file hash');
        
        try {
            // Check if we have a SHA256 hash for verification
            if (_currentFile.sha256 != null) {
                Logger.info('HCLDownloader: Verifying with SHA256 hash');
                
                // Calculate SHA256 hash asynchronously (this is the only method available)
                SuperHumanHashes.calculateSHA256Async(_tempFilePath, function(calculatedSha256:String) {
                    if (calculatedSha256 != null) {
                        calculatedSha256 = calculatedSha256.toLowerCase();
                        var expectedSha256 = _currentFile.sha256.toLowerCase();
                        
                        if (calculatedSha256 != expectedSha256) {
                            triggerError('SHA256 hash verification failed. Expected: ${expectedSha256}, Got: ${calculatedSha256}');
                            cleanupTempFiles();
                            return;
                        }
                        
                        Logger.info('SHA256 hash verification successful: ${calculatedSha256}');
                        finalizeDownload();
                    } else {
                        Logger.warning('Failed to calculate SHA256 hash');
                        // If we couldn't calculate the hash, don't proceed to verification
                        cleanupTempFiles();
                        triggerError('Could not calculate SHA256 hash for verification');
                    }
                });
                
                // Don't proceed further here - wait for the async callback
                return;
            }
            
            // If we got here, we don't have a SHA256 hash to verify against
            // This typically happens when using file IDs instead of hashes
            Logger.warning('HCLDownloader: Skipping hash verification - no SHA256 hash available. Using file ID stored in hash field');
            finalizeDownload();
            
        } catch (e:Dynamic) {
            triggerError('Exception during hash verification: ${e}');
            cleanupTempFiles();
        }
    }

    /**
     * Final step: Move file to cache
     */
    private function finalizeDownload():Void {
        // Update current step
        _currentStep = HCLDownloadStep.MovingFile;
        
        // Get target path from file cache
        var targetPath = _currentFile.path;
        
        // Ensure target directory exists
        var targetDir = haxe.io.Path.directory(targetPath);
        if (!FileSystem.exists(targetDir)) {
            try {
                FileSystem.createDirectory(targetDir);
            } catch (e:Dynamic) {
                triggerError('Failed to create target directory: ${e}');
                cleanupTempFiles();
                return;
            }
        }
        
        // Move temp file to target path (matching domdownload.sh approach of renaming verified file)
        try {
            if (FileSystem.exists(targetPath)) {
                FileSystem.deleteFile(targetPath);
            }
            FileSystem.rename(_tempFilePath, targetPath);
            Logger.info('HCLDownloader: Moved downloaded file from temp to: ${targetPath}');
        } catch (e:Dynamic) {
            triggerError('Failed to move downloaded file to cache: ${e}');
            cleanupTempFiles();
            return;
        }
        
        // Update file exists flag
        _currentFile.exists = true;
        
        // Set current step to complete
        _currentStep = HCLDownloadStep.Complete;
        
        // Trigger download complete
        for (f in _onDownloadComplete) f(this, _currentFile, true);
        
        // Reset download flag
        _isDownloading = false;
        
        // Clean up
        _currentFile = null;
        _accessToken = null;
        _downloadUrl = null;
    }

    /**
     * Clean up any temporary files
     */
    private function cleanupTempFiles():Void {
        if (_tempFilePath != null && FileSystem.exists(_tempFilePath)) {
            try {
                Logger.debug('HCLDownloader: Cleaning up temporary file: ${_tempFilePath}');
                FileSystem.deleteFile(_tempFilePath);
            } catch (e:Dynamic) {
                Logger.warning('Failed to delete temporary file: ${e}');
            }
        }
    }

    /**
     * Legacy method for completion handler (kept for compatibility)
     */
    private function _downloadFileComplete(e:Event):Void {
        // This is just a stub for backward compatibility
        Logger.debug('HCLDownloader: Legacy download complete handler called');
    }
    
    /**
     * Clean up download loader resources (legacy method)
     */
    private function _cleanupDownloadLoader():Void {
        if (_downloadLoader != null) {
            _downloadLoader.removeEventListener(Event.COMPLETE, _downloadFileComplete);
            _downloadLoader.removeEventListener(ProgressEvent.PROGRESS, function(e) {});
            _downloadLoader.removeEventListener(IOErrorEvent.IO_ERROR, function(e) {});
            _downloadLoader = null;
        }
        
        // Also clean up URLStream if it exists
        cleanupUrlStream();
    }

    /**
     * Trigger error event
     */
    private function triggerError(message:String):Void {
        // Update current step
        _currentStep = HCLDownloadStep.Error;
        
        Logger.error('HCLDownloader: ${message}');
        
        // Store current file before cleanup for event
        var currentFile = _currentFile;
        
        // Clean up resources
        cleanupTempFiles();
        _cleanupTokenLoader();
        _cleanupDownloadLoader();
        
        // Reset state
        _isDownloading = false;
        _currentFile = null;
        _downloadUrl = null;
        _currentToken = null;
        
        // Note: We don't clear the access token on error as it might still be valid
        // for other downloads
        
        // Notify listeners
        for (f in _onDownloadError) f(this, currentFile, message);
    }

    /**
     * Get custom resource from secrets
     */
    private function getCustomResource(resourceName:String):{name:String, url:String, useAuth:Bool, user:String, pass:String} {
        var secrets = SuperHumanInstaller.getInstance().config.secrets;
        if (secrets == null || secrets.custom_resource_url == null) return null;
        
        var resources:Array<Dynamic> = cast(secrets.custom_resource_url, Array<Dynamic>);
        for (i in 0...resources.length) {
            var resource = resources[i];
            if (Reflect.field(resource, "name") == resourceName) {
                return {
                    name: Reflect.field(resource, "name"),
                    url: Reflect.field(resource, "url"),
                    useAuth: Reflect.field(resource, "useAuth"),
                    user: Reflect.field(resource, "user"),
                    pass: Reflect.field(resource, "pass")
                };
            }
        }
        
        return null;
    }

    /**
     * Download file from custom URL
     */
    /**
     * Download a file from custom resource URL
     * @param file The cached file to download
     * @param resourceName The name of the custom resource to use
     */
    public function downloadFileWithCustomResource(file:SuperHumanCachedFile, resourceName:String):Void {
        // Store current file
        _currentFile = file;
        
        // Get resource from secrets
        var resource = getCustomResource(resourceName);
        if (resource == null) {
            triggerError("Invalid custom resource: " + resourceName);
            return;
        }
        
        // Notify download is starting
        for (f in _onDownloadStart) f(this, file);
        
        // Create temp file path
        var cacheDir = SuperHumanFileCache.getCacheDirectory();
        _tempFilePath = cacheDir + "/" + file.originalFilename + ".download";
        
        // Start download
        downloadFileFromCustomUrl(resource);
    }
    
    /**
     * Download file from custom URL using URLStream for efficient streaming
     */
    private function downloadFileFromCustomUrl(resource:{name:String, url:String, useAuth:Bool, user:String, pass:String}):Void {
        Logger.info('HCLDownloader: Downloading file from custom URL: ${resource.url}/${_currentFile.originalFilename}');
        
        // Prepare download URL
        var downloadUrl = resource.url;
        if (downloadUrl.charAt(downloadUrl.length - 1) != "/") downloadUrl += "/";
        downloadUrl += _currentFile.originalFilename;
        
        // Create URL request for file download
        var downloadRequest = new URLRequest(downloadUrl);
        
        // Add authentication if needed
        if (resource.useAuth && resource.user != null && resource.user.length > 0) {
            // Basic auth header
            var authString = resource.user + ":" + resource.pass;
            var base64Auth = haxe.crypto.Base64.encode(haxe.io.Bytes.ofString(authString));
            downloadRequest.requestHeaders = [new URLRequestHeader("Authorization", "Basic " + base64Auth)];
        }
        
        try {
            // Create and open file output for writing
            try {
                Logger.debug('HCLDownloader: Opening output file: ${_tempFilePath}');
                _fileOutput = sys.io.File.write(_tempFilePath, true);
            } catch (e:Dynamic) {
                triggerError('Failed to open output file: ${e}');
                return;
            }
            
            // Create URLStream for efficient streaming
            _urlStream = new URLStream();
            
            // Set up event listeners
            _urlStream.addEventListener(Event.OPEN, function(e:Event):Void {
                Logger.debug('HCLDownloader: Custom download connection opened');
            });
            
            _urlStream.addEventListener(ProgressEvent.PROGRESS, function(e:ProgressEvent):Void {
                // Store total bytes for the download
                _downloadBytesTotal = Std.int(e.bytesTotal);
                
                // Calculate progress percentage and notify listeners
                var progress:Float = 0;
                if (e.bytesTotal > 0) {
                    progress = e.bytesLoaded / e.bytesTotal;
                }
                
                Logger.debug('HCLDownloader: Custom download progress: ${Math.round(progress * 100)}% (${e.bytesLoaded}/${e.bytesTotal} bytes)');
                for (f in _onDownloadProgress) f(this, _currentFile, progress);
                
                // Process available bytes in the stream
                processAvailableBytes();
            });
            
            _urlStream.addEventListener(Event.COMPLETE, function(e:Event):Void {
                Logger.info('HCLDownloader: Custom download complete');
                
                // Process any remaining bytes in the stream
                processAvailableBytes();
                
                // Close the output file
                try {
                    if (_fileOutput != null) {
                        _fileOutput.close();
                        _fileOutput = null;
                    }
                } catch (e:Dynamic) {
                    Logger.error('HCLDownloader: Error closing output file: ${e}');
                }
                
                // Clean up stream
                cleanupUrlStream();
                
                // Verify the downloaded file
                verifyFileHash();
            });
            
            _urlStream.addEventListener(IOErrorEvent.IO_ERROR, function(e:IOErrorEvent):Void {
                Logger.error('HCLDownloader: Custom download error: ${e.text}, ID: ${e.errorID}');
                
                // Log all error fields for maximum diagnostic information
                var errorDetails = "";
                for (field in Reflect.fields(e)) {
                    try {
                        var value = Reflect.field(e, field);
                        if (value != null && field != "target") {
                            errorDetails += field + ": " + value + ", ";
                        }
                    } catch (_) {}
                }
                
                if (errorDetails.length > 0) {
                    Logger.error('HCLDownloader: Error details: ${errorDetails}');
                }
                
                // Close the output file
                try {
                    if (_fileOutput != null) {
                        _fileOutput.close();
                        _fileOutput = null;
                    }
                } catch (e:Dynamic) {
                    Logger.error('HCLDownloader: Error closing output file: ${e}');
                }
                
                cleanupUrlStream();
                triggerError('Failed to download file from custom URL: ${e.text}');
            });
            
            // Start the download
            Logger.debug('HCLDownloader: Starting custom file download from ${downloadUrl}');
            _urlStream.load(downloadRequest);
            _isDownloading = true;
            
        } catch (e:Dynamic) {
            // Close the output file if needed
            try {
                if (_fileOutput != null) {
                    _fileOutput.close();
                    _fileOutput = null;
                }
            } catch (_) {}
            
            cleanupUrlStream();
            triggerError('Failed to start custom file download: ${e}');
        }
    }

    /**
     * String representation for logging
     */
    public function toString():String {
        return "[HCLDownloader]";
    }
}

/**
 * Download step indicators for improved progress reporting with percentage ranges
 */
enum abstract HCLDownloadStep(String) to String {
    // Initialization steps
    var None = "None";
    
    // Steps 1-8 (0-10%)
    var GettingAccessToken = "Getting access token from refresh token"; // 1
    var SavingTokenRequest = "Saved token request payload"; // 2
    var SendingTokenRequest = "Sending token request"; // 3
    var ReceivedTokenResponse = "Received token response"; // 4
    var SavingTokenResponse = "Saved token response"; // 5
    var ParsingTokenJSON = "Parsed JSON response successfully"; // 6
    var FoundAccessToken = "Found accessToken field in response"; // 7
    var ObtainedAccessToken = "Successfully obtained access token"; // 8
    
    // Steps 9-13 (10-20%)
    var FetchingCatalog = "Fetching file catalog"; // 9
    var SendingCatalogRequest = "Sending catalog request"; // 10
    var ReceivedCatalogResponse = "Received catalog response"; // 11
    var SavingCatalogResponse = "Saved catalog response"; // 12
    var ParsingCatalogJSON = "Parsed catalog JSON successfully"; // 13
    
    // Steps 14-17 (20-30%)
    var SearchingFile = "Searching for file in catalog"; // 14
    var CatalogParsed = "Catalog parsed successfully"; // 15
    var FindingFile = "Finding file in catalog"; // 16
    var FoundFileID = "Found file ID in catalog"; // 17
    
    // Steps 18-19 (30-40%)
    var GettingDownloadURL = "Getting download URL for file ID"; // 18
    var RequestingDownloadURL = "Requesting download URL"; // 19
    
    // Step 20-74 (40-75%)
    var Downloading = "Downloading file"; // 20-74 (download progress)
    
    // Steps 75-89 (75-90%)
    var WritingFile = "Writing file to disk"; // 75-89
    
    // Steps 90-94 (90-95%)
    var VerifyingHash = "Verifying file checksum"; // 90-94
    
    // Steps 95-100 (95-100%)
    var MovingFile = "Moving file to cache"; // 95-99
    var Complete = "Download complete"; // 100
    
    // Error state
    var Error = "Error";
}

/**
 * Progress mapping to convert steps to percentage ranges
 */
class ProgressRangeMap {
    // Maps download steps to percentage ranges
    private static final ranges = [
        // Steps 1-8: 0-10%
        HCLDownloadStep.GettingAccessToken => { min: 0.0, max: 1.25 },
        HCLDownloadStep.SavingTokenRequest => { min: 1.25, max: 2.5 },
        HCLDownloadStep.SendingTokenRequest => { min: 2.5, max: 3.75 },
        HCLDownloadStep.ReceivedTokenResponse => { min: 3.75, max: 5.0 },
        HCLDownloadStep.SavingTokenResponse => { min: 5.0, max: 6.25 },
        HCLDownloadStep.ParsingTokenJSON => { min: 6.25, max: 7.5 },
        HCLDownloadStep.FoundAccessToken => { min: 7.5, max: 8.75 },
        HCLDownloadStep.ObtainedAccessToken => { min: 8.75, max: 10.0 },
        
        // Steps 9-13: 10-20%
        HCLDownloadStep.FetchingCatalog => { min: 10.0, max: 12.0 },
        HCLDownloadStep.SendingCatalogRequest => { min: 12.0, max: 14.0 },
        HCLDownloadStep.ReceivedCatalogResponse => { min: 14.0, max: 16.0 },
        HCLDownloadStep.SavingCatalogResponse => { min: 16.0, max: 18.0 },
        HCLDownloadStep.ParsingCatalogJSON => { min: 18.0, max: 20.0 },
        
        // Steps 14-17: 20-30%
        HCLDownloadStep.SearchingFile => { min: 20.0, max: 22.5 },
        HCLDownloadStep.CatalogParsed => { min: 22.5, max: 25.0 },
        HCLDownloadStep.FindingFile => { min: 25.0, max: 27.5 },
        HCLDownloadStep.FoundFileID => { min: 27.5, max: 30.0 },
        
        // Steps 18-19: 30-40%
        HCLDownloadStep.GettingDownloadURL => { min: 30.0, max: 35.0 },
        HCLDownloadStep.RequestingDownloadURL => { min: 35.0, max: 40.0 },
        
        // Step 20-74: 40-75% (download progress)
        HCLDownloadStep.Downloading => { min: 40.0, max: 75.0 },
        
        // Steps 75-89: 75-90%
        HCLDownloadStep.WritingFile => { min: 75.0, max: 90.0 },
        
        // Steps 90-94: 90-95%
        HCLDownloadStep.VerifyingHash => { min: 90.0, max: 95.0 },
        
        // Steps 95-100: 95-100%
        HCLDownloadStep.MovingFile => { min: 95.0, max: 99.0 },
        HCLDownloadStep.Complete => { min: 99.0, max: 100.0 }
    ];
    
    /**
     * Calculate progress percentage based on current step and optional sub-progress
     * @param step The current download step
     * @param subProgress Optional progress within the current step (0.0-1.0)
     * @return Float percentage (0-100)
     */
    public static function calculateProgress(step:HCLDownloadStep, ?subProgress:Float = 1.0):Float {
        // If we're in error state or none state, return 0
        if (step == HCLDownloadStep.Error || step == HCLDownloadStep.None) {
            return 0.0;
        }
        
        // If we're complete, return 100%
        if (step == HCLDownloadStep.Complete) {
            return 100.0;
        }
        
        // Ensure subProgress is between 0 and 1
        subProgress = Math.max(0.0, Math.min(1.0, subProgress));
        
        // Get the range for this step
        var range = ranges[step];
        if (range == null) {
            // If no range is defined for this step, return min progress
            return 0.0;
        }
        
        // Calculate percentage within the range
        return range.min + (range.max - range.min) * subProgress;
    }
}

/**
 * Executor context identifiers for HCLDownloader
 */
enum abstract HCLDownloaderContext(String) to String {
    var GetAccessToken = "HCLDownloader_GetAccessToken";
    var GetCatalog = "HCLDownloader_GetCatalog";
    var GetDownloadURL = "HCLDownloader_GetDownloadURL";
    var DownloadFile = "HCLDownloader_DownloadFile";
    var VerifyHash = "HCLDownloader_VerifyHash";
    var DownloadCustomFile = "HCLDownloader_DownloadCustomFile";
}
