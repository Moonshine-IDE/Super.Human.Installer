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
 * HCLDownloader handles the downloading of files from the HCL portal
 * using authentication tokens stored in SuperHumanSecrets.
 */
class HCLDownloader {

    // Singleton instance
    static var _instance:HCLDownloader;

    // Constants for URL and endpoints
    private static final MYHCL_PORTAL_URL:String = "https://my.hcltechsw.com";
    private static final MYHCL_API_URL:String = "https://api.hcltechsw.com";
    private static final MYHCL_TOKEN_URL:String = "https://api.hcltechsw.com/v1/apitokens/exchange";
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
    
    // Track whether we've tried alternative auth method
    var _altAuthMethodTried:Bool = false;
    
    // Current token being used
    var _currentToken:String;
    
    // When was the access token cached (initialized to 0 to avoid null Float errors)
    var _accessTokenCachedTime:Float = 0;
    
    // Access token cache duration in milliseconds (40 minutes to match domdownload.sh)
    private static final ACCESS_TOKEN_CACHE_DURATION:Float = 40 * 60 * 1000;

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
        
        // Reset alternative auth flag
        _altAuthMethodTried = false;
        
        // Get token from secrets
        var token = getHCLToken(tokenName);
        if (token == null) {
            triggerError("Invalid token: " + tokenName);
            return;
        }
        
        // Store token for alternative approach if needed
        _currentToken = token;
        
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
        
        // Check if we have a cached access token that isn't expired
        var currentTime = Date.now().getTime();
        if (_accessToken != null && _accessTokenCachedTime > 0) {
            var tokenAge = currentTime - _accessTokenCachedTime;
            if (tokenAge < ACCESS_TOKEN_CACHE_DURATION) {
                Logger.debug('HCLDownloader: Using cached access token (age: ${Math.round(tokenAge/1000)}s)');
                _isDownloading = true;
                getDownloadUrl();
                return;
            } else {
                Logger.debug('HCLDownloader: Cached access token expired (age: ${Math.round(tokenAge/1000)}s)');
                _accessToken = null;
            }
        }
        
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
            
            Logger.info('HCLDownloader: Successfully obtained access token');
            _accessToken = accessToken;
            _accessTokenCachedTime = Date.now().getTime();
            _isDownloading = true;
            
            // Continue to next step
            getDownloadUrl();
        };
        
        http.onError = function(error:String) {
            Logger.error('HCLDownloader: Token request failed with error: ${error}');
            
            // If this is our first attempt, try an alternative approach with form encoding
            if (!_altAuthMethodTried) {
                _altAuthMethodTried = true;
                Logger.info('HCLDownloader: First auth attempt failed, trying form-encoded approach');
                
                try {
                    // Create a new Http instance for the retry
                    var altHttp = new haxe.Http(MYHCL_TOKEN_URL);
                    
                    // Use form encoding instead of JSON
                    altHttp.setHeader("Content-Type", "application/x-www-form-urlencoded");
                    altHttp.setHeader("Accept", "application/json");
                    
                    // Set the same callbacks
                    altHttp.onData = http.onData;
                    altHttp.onError = http.onError;
                    altHttp.onStatus = http.onStatus;
                    
                    // Format data as standard OAuth parameters
                    var formData = "grant_type=refresh_token&refresh_token=" + StringTools.urlEncode(_currentToken);
                    Logger.debug('HCLDownloader: Alt request full data: ${formData}');
                    
                    altHttp.setPostData(formData);
                    Logger.debug('HCLDownloader: Sending alt token request to ${MYHCL_TOKEN_URL}');
                    altHttp.request(true);
                    return;
                } catch (e:Dynamic) {
                    Logger.error('HCLDownloader: Alt auth method failed: ${e}');
                }
            }
            
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
        
        Logger.info('HCLDownloader: Successfully obtained access token');
        _accessToken = accessToken;
        
        // Continue to next step
        getDownloadUrl();
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
        
        // If this is our first attempt, try an alternative approach
        if (!_altAuthMethodTried) {
            _altAuthMethodTried = true;
            Logger.info('HCLDownloader: First auth attempt failed, trying form-encoded approach');
            
            try {
            // Create an alternative approach using URL-encoded form data like the bash script
            var request = new URLRequest(MYHCL_TOKEN_URL);
            request.method = URLRequestMethod.POST;
            request.followRedirects = true;
            
            // Use form encoding instead of JSON (matching domdownload.sh fallback)
            request.requestHeaders = [
                new URLRequestHeader("Content-Type", "application/x-www-form-urlencoded"),
                new URLRequestHeader("Accept", "application/json"),
                new URLRequestHeader("User-Agent", "curl/7.68.0") // Consistent user agent
            ];
            
            // Format data as standard OAuth parameters
            var formData = "grant_type=refresh_token&refresh_token=" + StringTools.urlEncode(_currentToken);
            Logger.debug('HCLDownloader: Alt request data: ${formData.substr(0, 15)}...');
            request.data = formData;
                
                _tokenLoader = new URLLoader();
                _tokenLoader.dataFormat = URLLoaderDataFormat.TEXT;
                _tokenLoader.addEventListener(Event.COMPLETE, _accessTokenLoaderComplete);
                _tokenLoader.addEventListener(IOErrorEvent.IO_ERROR, _accessTokenLoaderError);
                _tokenLoader.addEventListener(Event.OPEN, function(e) {
                    Logger.debug('HCLDownloader: Alt token request connection opened');
                });
                _tokenLoader.addEventListener(ProgressEvent.PROGRESS, function(e) {
                    Logger.debug('HCLDownloader: Alt token request progress: ${e.bytesLoaded}/${e.bytesTotal}');
                });
                
                Logger.debug('HCLDownloader: Sending alt token request to ${MYHCL_TOKEN_URL}');
                _tokenLoader.load(request);
                return;
            } catch (e:Dynamic) {
                Logger.error('HCLDownloader: Alt auth method failed: ${e}');
            }
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
    private function getDownloadUrl():Void {
        Logger.info('HCLDownloader: Getting download URL for file ID: ${_currentFile.hash}');
        
        // Construct the download URL (using the file hash as the ID)
        var downloadUrl = MYHCL_DOWNLOAD_URL_PREFIX + _currentFile.hash + MYHCL_DOWNLOAD_URL_SUFFIX;
        Logger.debug('HCLDownloader: Requesting download URL from: ${downloadUrl}');
        
        // Use Haxe Http for consistency with token request
        var http = new haxe.Http(downloadUrl);
        
        // Add authorization header with bearer token
        http.setHeader("Authorization", "Bearer " + _accessToken);
        http.setHeader("Accept", "application/json");
        http.setHeader("User-Agent", "curl/7.68.0"); // Mimic curl's user agent
        
        // Add callback for successful response
        http.onData = function(data:String) {
            Logger.debug('HCLDownloader: Received download URL response: ${data}');
            
            // Save response to a file for debugging
            try {
                sys.io.File.saveContent("download_url_response.json", data);
                Logger.debug('HCLDownloader: Saved download URL response to download_url_response.json');
            } catch (e:Dynamic) {
                Logger.error('HCLDownloader: Failed to save download URL response to file: ${e}');
            }
            
            // Try to parse response as JSON (in case of error)
            try {
                var responseJson = haxe.Json.parse(data);
                
                // If we got valid JSON, it's likely an error message
                if (responseJson.summary != null) {
                    triggerError('Failed to get download URL: ${responseJson.summary}');
                    return;
                }
            } catch (e:Dynamic) {
                // Not JSON, this is expected as we're looking for a redirect URL
            }
            
            // The response should contain the download URL
            _downloadUrl = StringTools.trim(data);
            
            if (_downloadUrl == null || _downloadUrl.length == 0) {
                triggerError("Failed to get download URL: No redirect URL received");
                return;
            }
            
            Logger.debug('HCLDownloader: Got download URL: ${_downloadUrl}');
            
            // Continue to next step
            downloadFile();
        };
        
        // Add callback for error
        http.onError = function(error:String) {
            Logger.error('HCLDownloader: Download URL request failed with error: ${error}');
            triggerError('Failed to get download URL: ${error}');
        };
        
        // Add callback for HTTP status
        http.onStatus = function(status:Int) {
            Logger.debug('HCLDownloader: Download URL HTTP status code: ${status}');
        };
        
        // Send the request
        try {
            Logger.debug('HCLDownloader: Sending download URL request to ${downloadUrl}');
            http.request(false); // false = GET request
        } catch (e:Dynamic) {
            triggerError('Failed to send download URL request: ${e}');
        }
    }

    /**
     * Step 3: Download the file
     */
    private function downloadFile():Void {
        Logger.info('HCLDownloader: Downloading file from URL: ${_downloadUrl}');
        
        // Create a temp file path with .download extension (matching domdownload.sh)
        var cacheDir = SuperHumanFileCache.getCacheDirectory();
        _tempFilePath = cacheDir + "/" + _currentFile.originalFilename + ".download";
        
        // For binary downloads, we still need to use URLLoader since haxe.Http doesn't
        // have built-in support for binary data with progress tracking.
        var downloadRequest = new URLRequest(_downloadUrl);
        downloadRequest.requestHeaders = [
            new URLRequestHeader("Authorization", "Bearer " + _accessToken),
            new URLRequestHeader("User-Agent", "curl/7.68.0") // Match curl's user agent
        ];
        
        // Set up file download loader
        _downloadLoader = new URLLoader();
        _downloadLoader.dataFormat = URLLoaderDataFormat.BINARY;
        _downloadLoader.addEventListener(Event.COMPLETE, _downloadFileComplete);
        _downloadLoader.addEventListener(ProgressEvent.PROGRESS, _downloadFileProgress);
        _downloadLoader.addEventListener(IOErrorEvent.IO_ERROR, function(e:IOErrorEvent) {
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
            
            triggerError('Failed to download file: ${e.text}');
            _cleanupDownloadLoader();
        });
        
        try {
            Logger.debug('HCLDownloader: Starting file download from ${_downloadUrl}');
            _downloadLoader.load(downloadRequest);
        } catch (e:Dynamic) {
            triggerError('Failed to start file download: ${e}');
            _cleanupDownloadLoader();
        }
    }
    
    /**
     * Handle file download progress
     */
    private function _downloadFileProgress(e:ProgressEvent):Void {
        // Calculate progress percentage and notify listeners
        var progress:Float = 0;
        if (e.bytesTotal > 0) {
            progress = e.bytesLoaded / e.bytesTotal;
        }
        Logger.debug('HCLDownloader: Download progress: ${Math.round(progress * 100)}% (${e.bytesLoaded}/${e.bytesTotal} bytes)');
        for (f in _onDownloadProgress) f(this, _currentFile, progress);
    }
    
    /**
     * Handle file download completion
     */
    private function _downloadFileComplete(e:Event):Void {
        var data:ByteArray = cast _downloadLoader.data;
        Logger.info('HCLDownloader: Download complete, received ${data != null ? data.length : 0} bytes');
        
        // Clean up loader
        _cleanupDownloadLoader();
        
        if (data == null || data.length == 0) {
            triggerError("Failed to download file: No data received");
            return;
        }
        
        // Check for tiny files (less than 1KB) which may indicate an error JSON response
        if (data.length < 1024) {
            try {
                // Try to parse as JSON to see if it's an error message
                data.position = 0;
                var errorText = data.readUTFBytes(data.length);
                var errorJson = haxe.Json.parse(errorText);
                
                if (Reflect.hasField(errorJson, "summary")) {
                    triggerError('Download failed: ${errorJson.summary}');
                    return;
                }
            } catch (e:Dynamic) {
                // Not a JSON error, continue processing
                Logger.debug('HCLDownloader: Small file but not JSON error, continuing: ${e}');
            }
        }
        
        // Write data to temp file
        try {
            var output = sys.io.File.write(_tempFilePath, true);
            data.position = 0; // Reset position to start of ByteArray
            
            // Write in chunks to avoid potential memory issues with very large files
            var chunkSize:UInt = 4096; // 4KB chunks
            var buffer = new ByteArray();
            buffer.length = chunkSize;
            
            while (data.position < data.length) {
                var bytesToRead:Int = Std.int(Math.min(chunkSize, data.length - data.position));
                data.readBytes(buffer, 0, bytesToRead);
                
                for (i in 0...bytesToRead) {
                    output.writeByte(buffer[i]);
                }
            }
            
            output.close();
            Logger.debug('HCLDownloader: Saved downloaded data to temporary file: ${_tempFilePath}');
        } catch (e:Dynamic) {
            triggerError('Failed to write downloaded data to temp file: ${e}');
            return;
        }
        
        // Verify file hash
        verifyFileHash();
    }
    
    /**
     * Clean up download loader resources
     */
    private function _cleanupDownloadLoader():Void {
        if (_downloadLoader != null) {
            _downloadLoader.removeEventListener(Event.COMPLETE, _downloadFileComplete);
            _downloadLoader.removeEventListener(ProgressEvent.PROGRESS, _downloadFileProgress);
            // We're using an anonymous function for IOErrorEvent now, which can't be directly removed
            // Instead, we simply set _downloadLoader to null and let the garbage collector handle it
            _downloadLoader = null;
        }
    }

    /**
     * Step 4: Verify the file hash
     */
    private function verifyFileHash():Void {
        Logger.info('HCLDownloader: Verifying file hash');
        
        try {
            // Use SuperHumanHashes to calculate the hash
            var calculatedHash = SuperHumanHashes.calculateMD5(_tempFilePath);
            
            if (calculatedHash == null) {
                triggerError("Failed to verify file hash: No hash calculated");
                cleanupTempFiles();
                return;
            }
            
            // Compare with expected hash (case insensitive) - following domdownload.sh approach
            var expectedHash = _currentFile.hash.toLowerCase();
            calculatedHash = calculatedHash.toLowerCase();
            
            if (calculatedHash != expectedHash) {
                triggerError('Hash verification failed. Expected: ${expectedHash}, Got: ${calculatedHash}');
                cleanupTempFiles();
                return;
            }
            
            Logger.info('Hash verification successful: ${calculatedHash}');
            
            // Also calculate SHA256 hash if needed
            if (_currentFile.sha256 != null) {
                // Calculate SHA256 hash asynchronously
                SuperHumanHashes.calculateSHA256Async(_tempFilePath, function(calculatedSha256:String) {
                    if (calculatedSha256 != null && calculatedSha256.toLowerCase() != _currentFile.sha256.toLowerCase()) {
                        Logger.warning('SHA256 hash verification failed. Expected: ${_currentFile.sha256}, Got: ${calculatedSha256}');
                    } else {
                        Logger.info('SHA256 hash verification successful');
                    }
                });
            }
            
            // Hash verified, move file to cache
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
     * Trigger error event
     */
    private function triggerError(message:String):Void {
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
     * Download file from custom URL
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
        
        // Set up file download loader
        _downloadLoader = new URLLoader();
        _downloadLoader.dataFormat = URLLoaderDataFormat.BINARY;
        _downloadLoader.addEventListener(Event.COMPLETE, _downloadFileComplete);
        _downloadLoader.addEventListener(ProgressEvent.PROGRESS, _downloadFileProgress);
        _downloadLoader.addEventListener(IOErrorEvent.IO_ERROR, function(e:IOErrorEvent) {
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
            
            triggerError('Failed to download file from custom URL: ${e.text}');
            _cleanupDownloadLoader();
        });
        
        try {
            Logger.debug('HCLDownloader: Starting custom file download from ${downloadUrl}');
            _downloadLoader.load(downloadRequest);
            _isDownloading = true;
        } catch (e:Dynamic) {
            triggerError('Failed to start custom file download: ${e}');
            _cleanupDownloadLoader();
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
 * Executor context identifiers for HCLDownloader
 */
enum abstract HCLDownloaderContext(String) to String {
    var GetAccessToken = "HCLDownloader_GetAccessToken";
    var GetDownloadURL = "HCLDownloader_GetDownloadURL";
    var DownloadFile = "HCLDownloader_DownloadFile";
    var VerifyHash = "HCLDownloader_VerifyHash";
    var DownloadCustomFile = "HCLDownloader_DownloadCustomFile";
}
