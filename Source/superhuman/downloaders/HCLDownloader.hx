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
import sys.thread.Thread;
import sys.thread.Mutex;
import sys.thread.Deque;
import openfl.events.Event;
import openfl.events.EventDispatcher;
import openfl.events.EventType;
import openfl.errors.Error;

/**
 * ThreadMessageEvent - Custom event class for thread message communication
 */
class ThreadMessageEvent extends Event {
    public var messageData:Dynamic;
    
    public function new(type:String, data:Dynamic) {
        super(type);
        this.messageData = data;
    }
    
    override public function clone():Event {
        return new ThreadMessageEvent(type, messageData);
    }
}

/**
 * ThreadMessage - Represents a message to be passed between threads
 */
class ThreadMessage {
    public var action:String;
    public var data:Dynamic;
    
    public function new(action:String, data:Dynamic) {
        this.action = action;
        this.data = data;
    }
}

/**
 * ThreadCommunicator - Handles communication between threads
 */
class ThreadCommunicator extends EventDispatcher {
    // Singleton instance
    private static var _instance:ThreadCommunicator;
    
    // Message queue for communication between threads
    private var _messageQueue:Deque<ThreadMessage>;
    
    // Update interval (ms)
    private static inline var UPDATE_INTERVAL:Int = 50;
    
    // Active timer for processing messages
    private var _timer:haxe.Timer;
    
    /**
     * Get the singleton instance
     */
    public static function getInstance():ThreadCommunicator {
        if (_instance == null) {
            _instance = new ThreadCommunicator();
        }
        return _instance;
    }
    
    /**
     * Private constructor - use getInstance()
     */
    private function new() {
        super();
        _messageQueue = new Deque<ThreadMessage>();
        startProcessing();
    }
    
    /**
     * Post a message from a worker thread to be processed on the main thread
     */
    public function postThreadMessage(action:String, data:Dynamic):Void {
        _messageQueue.add(new ThreadMessage(action, data));
    }
    
    /**
     * Start processing messages
     */
    public function startProcessing():Void {
        if (_timer != null) {
            _timer.stop();
        }
        
        _timer = new haxe.Timer(UPDATE_INTERVAL);
        _timer.run = processMessages;
    }
    
    /**
     * Stop processing messages
     */
    public function stopProcessing():Void {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }
    
    /**
     * Process messages in the queue
     */
    private function processMessages():Void {
        var message = _messageQueue.pop(false);
        while (message != null) {
            // Dispatch the message as a custom ThreadMessageEvent
            var event = new ThreadMessageEvent(message.action, message.data);
            dispatchEvent(event);
            
            // Get next message
            message = _messageQueue.pop(false);
        }
    }
}

/**
 * ThreadedNetworkExecutor - A specialized executor for handling HTTP operations in a separate thread
 * This prevents blocking the main UI thread during network operations
 */
class ThreadedNetworkExecutor extends prominic.sys.io.AbstractExecutor {
    // ThreadCommunicator message action constants
    public static inline final ACTION_COMPLETE = "network_complete";
    public static inline final ACTION_ERROR = "network_error";
    public static inline final ACTION_PROGRESS = "network_progress";
    public static inline final ACTION_REDIRECT = "network_redirect";
    
    // Thread communicator for passing messages between threads
    private static var _communicator:ThreadCommunicator;
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
    private var _onProgress:ChainedList<(ThreadedNetworkExecutor, Float)->Void, ThreadedNetworkExecutor>;
    // Tracks if a redirect is being followed
    private var _followRedirect:Bool = false;
    // Tracking for redirect chain 
    private var _redirectCount:Int = 0;
    // Threading components
    private var _thread:Thread;
    private var _mutex:Mutex;
    private var _progressMutex:Mutex;
    private var _threadActive:Bool = false;
    
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
     * Event triggered during progress
     */
    public var onProgress(get, never):ChainedList<(ThreadedNetworkExecutor, Float)->Void, ThreadedNetworkExecutor>;
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
     * Execute the HTTP request in a separate thread
     */
    public function execute(?extraArgs:Array<String>, ?workingDirectory:String):ThreadedNetworkExecutor {
        // Don't start if already running
        if (_running) return this;
        
        _startTime = Sys.time();
        _running = true;
        _hasErrors = false;
        _threadActive = true;
        
        // Initialize thread synchronization
        _mutex = new Mutex();
        _progressMutex = new Mutex();
        
        // Initialize thread communicator if needed
        if (_communicator == null) {
            _communicator = ThreadCommunicator.getInstance();
            
            // Set up event handlers for thread messages
            _communicator.addEventListener(ACTION_COMPLETE, function(e:ThreadMessageEvent) {
                var data = e.messageData;
                if (data != null && data.executor == this) {
                    _finalizeExecution(data.exitCode);
                }
            });
            
            _communicator.addEventListener(ACTION_ERROR, function(e:ThreadMessageEvent) {
                var data = e.messageData;
                if (data != null && data.executor == this) {
                    for (f in _onStdErr) f(this, data.message);
                    _finalizeExecution(1);
                }
            });
            
            _communicator.addEventListener(ACTION_PROGRESS, function(e:ThreadMessageEvent) {
                var data = e.messageData;
                if (data != null && data.executor == this) {
                    for (f in _onProgress) f(this, data.progress);
                }
            });
            
            _communicator.addEventListener(ACTION_REDIRECT, function(e:ThreadMessageEvent) {
                var data = e.messageData;
                if (data != null && data.executor == this) {
                    _handleRedirect(data.headers);
                }
            });
        }
        
        // Trigger start event
        for (f in _onStart) f(this);
        
        // Create and start a new thread for the network operation
        _thread = Thread.create(function() {
            // Run in a try/catch block to ensure we handle any exceptions
            try {
                // Perform the actual HTTP request based on type
                if (_binary) {
                    _executeBinaryRequestThreaded();
                } else {
                    _executeTextRequestThreaded();
                }
            } catch (e:Dynamic) {
                // Acquire mutex before setting shared state
                _mutex.acquire();
                _hasErrors = true;
                var errorMsg = 'Thread exception: ${e}';
                _mutex.release();
                
                // Post the error back to the main thread via communicator
                _communicator.postThreadMessage(ACTION_ERROR, {
                    executor: this,
                    message: errorMsg
                });
            }
        });
        
        return this;
    }
    
    /**
     * Legacy non-threaded text request method (kept for compatibility)
     */
    private function _executeTextRequest():Void {
        // Just delegate to the threaded implementation
        _executeTextRequestThreaded();
    }
    
    /**
     * Execute text-based HTTP request in a separate thread
     * This prevents blocking the main UI thread
     */
    private function _executeTextRequestThreaded():Void {
        var http = new haxe.Http(_url);
        
        // Set headers in the worker thread
        for (key in _headers.keys()) {
            http.setHeader(key, _headers.get(key));
        }
        
        // Set callbacks that will run in the worker thread
        http.onData = function(data:String) {
            // Thread-safe update of shared state using mutex
            _mutex.acquire();
            _responseData = data;
            _mutex.release();
            
            // Post the completion back to the main thread via communicator
            _communicator.postThreadMessage(ACTION_COMPLETE, {
                executor: this,
                exitCode: 0
            });
        };
        
        http.onError = function(error:String) {
            // Thread-safe update of shared state using mutex
            _mutex.acquire();
            _hasErrors = true;
            var errorMessage = error; // Make local copy for closure
            _mutex.release();
            
            // Post the error back to the main thread via communicator
            _communicator.postThreadMessage(ACTION_ERROR, {
                executor: this,
                message: errorMessage
            });
        };
        
        http.onStatus = function(status:Int) {
            if (status >= 300 && status < 400 && _followRedirect) {
                // Store headers for redirect handling
                var responseHeaders = http.responseHeaders;
                
                // Post redirect handling back to the main thread via communicator
                _communicator.postThreadMessage(ACTION_REDIRECT, {
                    executor: this,
                    headers: responseHeaders
                });
                return;
            }
            
            // Thread-safe update of response headers using mutex
            _mutex.acquire();
            _responseHeaders = http.responseHeaders;
            _mutex.release();
        };
        
        // Execute request in the worker thread
        try {
            if (_method == "POST" && _postData != null) {
                http.setPostData(_postData);
                http.request(true);
            } else {
                http.request(false);
            }
        } catch (e:Dynamic) {
            // Thread-safe update of shared state using mutex
            _mutex.acquire();
            _hasErrors = true;
            var errorMessage = 'Exception: ${e}'; // Make local copy for closure
            _mutex.release();
            
            // Post the exception back to the main thread via communicator
            _communicator.postThreadMessage(ACTION_ERROR, {
                executor: this,
                message: errorMessage
            });
        }
    }
    
    /**
     * Legacy non-threaded binary request method (kept for compatibility)
     */
    private function _executeBinaryRequest():Void {
        // Just delegate to the threaded implementation
        _executeBinaryRequestThreaded();
    }
    
    /**
     * Execute binary HTTP request in a separate thread
     * This prevents blocking the main UI thread
     */
    private function _executeBinaryRequestThreaded():Void {
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
        
        // Set up event listeners - these run in the worker thread but will post back to main thread
        loader.addEventListener(openfl.events.Event.COMPLETE, function(e) {
            // Thread-safe update of shared state
            _mutex.acquire();
            _responseData = loader.data;
            _mutex.release();
            
            // Clean up event listeners
            loader.removeEventListener(openfl.events.Event.COMPLETE, function(e) {});
            loader.removeEventListener(openfl.events.ProgressEvent.PROGRESS, function(e) {});
            loader.removeEventListener(openfl.events.IOErrorEvent.IO_ERROR, function(e) {});
            
            // Post completion back to main thread via communicator
            _communicator.postThreadMessage(ACTION_COMPLETE, {
                executor: this,
                exitCode: 0
            });
        });
        
        loader.addEventListener(openfl.events.ProgressEvent.PROGRESS, function(e:openfl.events.ProgressEvent) {
            // Thread-safe update of progress data
            _progressMutex.acquire();
            _bytesLoaded = Std.int(e.bytesLoaded);
            _bytesTotal = Std.int(e.bytesTotal);
            
            // Calculate progress
            var progress:Float = 0;
            if (_bytesTotal > 0) {
                progress = _bytesLoaded / _bytesTotal;
            }
            _progressMutex.release();
            
            // Post progress update back to main thread via communicator
            _communicator.postThreadMessage(ACTION_PROGRESS, {
                executor: this,
                progress: (_bytesTotal > 0) ? (_bytesLoaded / _bytesTotal) : 0
            });
        });
        
        loader.addEventListener(openfl.events.IOErrorEvent.IO_ERROR, function(e:openfl.events.IOErrorEvent) {
            // Thread-safe update of shared state
            _mutex.acquire();
            _hasErrors = true;
            var errorMessage = e.text; // Make local copy for closure
            _mutex.release();
            
            // Clean up event listeners
            loader.removeEventListener(openfl.events.Event.COMPLETE, function(e) {});
            loader.removeEventListener(openfl.events.ProgressEvent.PROGRESS, function(e) {});
            loader.removeEventListener(openfl.events.IOErrorEvent.IO_ERROR, function(e) {});
            
            // Post error back to main thread via communicator
            _communicator.postThreadMessage(ACTION_ERROR, {
                executor: this,
                message: errorMessage
            });
        });
        
        // Execute request
        try {
            loader.load(request);
        } catch (e:Dynamic) {
            // Thread-safe update of shared state
            _mutex.acquire();
            _hasErrors = true;
            var errorMessage = 'Exception: ${e}'; // Make local copy for closure
            _mutex.release();
            
            // Post exception back to main thread via communicator
            _communicator.postThreadMessage(ACTION_ERROR, {
                executor: this,
                message: errorMessage
            });
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
        var redirectExecutor = new ThreadedNetworkExecutor(location, _method, _headers, _postData, _binary);
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
            var networkExecutor:ThreadedNetworkExecutor = cast executor;
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
     * @param newToken The new refresh token value
     * @param accessToken The current access token to save
     */
    private function updateHCLToken(tokenName:String, newToken:String, ?accessToken:String = null):Void {
        var secrets = SuperHumanInstaller.getInstance().config.secrets;
        if (secrets == null || secrets.hcl_download_portal_api_keys == null) {
            Logger.error('HCLDownloader: Cannot update token - no secrets found');
            return;
        }
        
        var keys:Array<Dynamic> = cast(secrets.hcl_download_portal_api_keys, Array<Dynamic>);
        for (i in 0...keys.length) {
            var key = keys[i];
            if (Reflect.field(key, "name") == tokenName) {
                // Update the refresh token
                Reflect.setField(key, "key", newToken);
                
                // Also store the access token if provided
                if (accessToken != null) {
                    // Check if the access_token field exists, if not create it
                    if (!Reflect.hasField(key, "access_token")) {
                        Reflect.setField(key, "access_token", accessToken);
                    } else {
                        // Update the existing access token
                        Reflect.setField(key, "access_token", accessToken);
                    }
                    Logger.info('HCLDownloader: Stored access token for [${tokenName}]');
                }
                
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
     * @param tokenName The name of the token to retrieve
     * @param accessTokenOnly If true, only return the access token (not the refresh token)
     * @return The token value, or null if not found
     */
    private function getHCLToken(tokenName:String, accessTokenOnly:Bool = false):String {
        var secrets = SuperHumanInstaller.getInstance().config.secrets;
        if (secrets == null || secrets.hcl_download_portal_api_keys == null) return null;
        
        var keys:Array<Dynamic> = cast(secrets.hcl_download_portal_api_keys, Array<Dynamic>);
        for (i in 0...keys.length) {
            var key = keys[i];
            if (Reflect.field(key, "name") == tokenName) {
                // If we only want the access token and it exists, return it
                if (accessTokenOnly && Reflect.hasField(key, "access_token")) {
                    return Reflect.field(key, "access_token");
                }
                
                // Otherwise return the refresh token
                return Reflect.field(key, "key");
            }
        }
        
        return null;
    }
    
    /**
     * Check if a token has a saved access token
     * @param tokenName The name of the token to check
     * @return True if the token has a saved access token
     */
    private function hasAccessToken(tokenName:String):Bool {
        var secrets = SuperHumanInstaller.getInstance().config.secrets;
        if (secrets == null || secrets.hcl_download_portal_api_keys == null) return false;
        
        var keys:Array<Dynamic> = cast(secrets.hcl_download_portal_api_keys, Array<Dynamic>);
        for (i in 0...keys.length) {
            var key = keys[i];
            if (Reflect.field(key, "name") == tokenName) {
                return Reflect.hasField(key, "access_token");
            }
        }
        
        return false;
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
        
        // Get target path from file cache
        var targetPath = file.path;
        
        // Check if file already exists at the target path
        if (FileSystem.exists(targetPath)) {
            // File exists - use temporary path with .download extension
            var cacheDir = SuperHumanFileCache.getCacheDirectory();
            _tempFilePath = cacheDir + "/" + file.originalFilename + ".download";
            Logger.info('HCLDownloader: File already exists at target path, using temp file: ${_tempFilePath}');
        } else {
            // File does not exist - download directly to target path
            _tempFilePath = targetPath;
            
            // Ensure target directory exists
            var targetDir = haxe.io.Path.directory(targetPath);
            if (!FileSystem.exists(targetDir)) {
                try {
                    FileSystem.createDirectory(targetDir);
                } catch (e:Dynamic) {
                    triggerError('Failed to create target directory: ${e}');
                    return;
                }
            }
            
            Logger.info('HCLDownloader: File missing, downloading directly to: ${_tempFilePath}');
        }
        
        // Initialize thread synchronization
        _mutex = new Mutex();
        _progressMutex = new Mutex();
        
        // Start the entire download process in a single worker thread
        // This includes token request, catalog fetching, URL redirection, and file download
        _thread = Thread.create(function() {
            try {
                // Start the download process by getting access token
                getAccessTokenThreaded(token);
            } catch (e:Dynamic) {
                // Acquire mutex before setting shared state
                _mutex.acquire();
                var errorMsg = 'Thread exception: ${e}';
                _mutex.release();
                
                // Post the error via communicator
                if (_communicator != null) {
                    _communicator.postThreadMessage(ThreadedNetworkExecutor.ACTION_ERROR, {
                        message: errorMsg
                    });
                } else {
                    triggerError(errorMsg);
                }
            }
        });
    }
    
    /**
     * Threaded version of getAccessToken
     * All pre-download operations run in the worker thread
     */
    private function getAccessTokenThreaded(refreshToken:String):Void {
        if (_isDownloading) {
            Logger.warning('HCLDownloader: Already downloading a file');
            return;
        }
        
        // Update current step with progress reporting
        updateStep(HCLDownloadStep.GettingAccessToken);
        
        // First check if we already have a saved access token for this token name
        if (hasAccessToken(_currentTokenName)) {
            // Use the existing access token instead of using the refresh token
            _accessToken = getHCLToken(_currentTokenName, true); // true = get access token only
            
            if (_accessToken != null) {
                Logger.info('HCLDownloader: Using saved access token for ${_currentTokenName} (threaded)');
                updateStep(HCLDownloadStep.ObtainedAccessToken);
                _isDownloading = true;
                
                // Continue to next step - fetch catalog to find file ID
                fetchCatalogThreaded();
                return;
            } else {
                Logger.warning('HCLDownloader: Failed to get saved access token, will try refresh token (threaded)');
            }
        }
        
        // If we got here, we need to use the refresh token to get a new access token
        // Reset access token to be safe
        _accessToken = null;
        
        Logger.info('HCLDownloader: Getting access token from refresh token (threaded)');
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
            updateStep(HCLDownloadStep.ReceivedTokenResponse);
            Logger.debug('HCLDownloader: Received token response (threaded)');
            
            // Process response - similar to _accessTokenLoaderComplete
            var responseJson:Dynamic;
            try {
                responseJson = haxe.Json.parse(data);
                updateStep(HCLDownloadStep.ParsingTokenJSON);
                Logger.debug('HCLDownloader: Parsed JSON response successfully (threaded)');
            } catch (e:Dynamic) {
                triggerError('Failed to parse token response: ${e}');
                return;
            }
            
            // Extract refresh token first - this is CRITICAL as the refresh token is rotated on each use
            var newRefreshToken:String = null;
            if (Reflect.hasField(responseJson, "refreshToken")) {
                newRefreshToken = Reflect.field(responseJson, "refreshToken");
                Logger.debug('HCLDownloader: Found new rotated refresh token in response (threaded)');
                
                // Save the new refresh token back to SuperHumanSecrets
                if (newRefreshToken != null && newRefreshToken != refreshToken) {
                    // Use custom thread communicator to update token on main thread
                    var communicator = ThreadCommunicator.getInstance();
                    communicator.postThreadMessage("token_update", {
                        tokenName: _currentTokenName,
                        newToken: newRefreshToken
                    });
                    
                    // Set up listener on main thread if it doesn't exist
                    _setupTokenUpdateListener();
                }
            }
            
            // Extract access token - standard OAuth responses use "access_token" field
            var accessToken:String = null;
            
            // Try standard OAuth field first
            if (Reflect.hasField(responseJson, "access_token")) {
                accessToken = Reflect.field(responseJson, "access_token");
                updateStep(HCLDownloadStep.FoundAccessToken);
                Logger.debug('HCLDownloader: Found access_token field in response (threaded)');
            } 
            // Try HCL specific field if standard not found
            else if (Reflect.hasField(responseJson, "accessToken")) {
                accessToken = Reflect.field(responseJson, "accessToken");
                updateStep(HCLDownloadStep.FoundAccessToken);
                Logger.debug('HCLDownloader: Found accessToken field in response (threaded)');
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
                
                // Log for debugging
                Logger.error('HCLDownloader: Token error (threaded): ${errorMessage}');
                triggerError('Failed to get access token: ${errorMessage}');
                return;
            }
            
            Logger.info('HCLDownloader: Successfully obtained fresh access token (threaded)');
            updateStep(HCLDownloadStep.ObtainedAccessToken);
            _accessToken = accessToken;
            _isDownloading = true;
            
            // Store the access token for future use - this is critical to avoid using refresh token each time
            // Use custom thread communicator to update token on main thread (with both refresh and access tokens)
            if (_communicator == null) {
                _communicator = ThreadCommunicator.getInstance();
            }
            
            _communicator.postThreadMessage("token_update_with_access", {
                tokenName: _currentTokenName,
                newToken: newRefreshToken != null ? newRefreshToken : refreshToken, // Use new token if available
                accessToken: accessToken
            });
            
            // Set up listener on main thread if it doesn't exist
            _setupAccessTokenUpdateListener();
            
            // Continue to next step - fetch catalog to find file ID
            fetchCatalogThreaded();
        };
        
        http.onError = function(error:String) {
            Logger.error('HCLDownloader: Token request failed with error (threaded): ${error}');
            triggerError('Failed to get access token: ${error}');
        };
        
        http.onStatus = function(status:Int) {
            Logger.debug('HCLDownloader: HTTP status code (threaded): ${status}');
        };
        
        // Format data as JSON exactly as in the bash script
        var payload = { refreshToken: refreshToken };
        var jsonPayload = haxe.Json.stringify(payload);
        
        updateStep(HCLDownloadStep.SendingTokenRequest);
        
        // Send the request
        try {
            Logger.debug('HCLDownloader: Sending token request to ${MYHCL_TOKEN_URL} (threaded)');
            http.setPostData(jsonPayload);
            http.request(true); // true = POST request
        } catch (e:Dynamic) {
            triggerError('Failed to send token request: ${e}');
        }
    }
    
    /**
     * Threaded version of fetchCatalog
     */
    private function fetchCatalogThreaded():Void {
        // Update current step
        _currentStep = HCLDownloadStep.FetchingCatalog;
        
        Logger.info('HCLDownloader: Fetching file catalog (threaded)');
        
        // Use Haxe Http for consistency
        var http = new haxe.Http(MYHCL_CATALOG_URL);
        
        // Add authorization header with bearer token
        http.setHeader("Authorization", "Bearer " + _accessToken);
        http.setHeader("Accept", "application/json");
        http.setHeader("User-Agent", "curl/7.68.0"); // Mimic curl's user agent
        
        // Add callback for successful response
        http.onData = function(data:String) {
            Logger.debug('HCLDownloader: Received catalog response (threaded)');
            
            // Save response to a file for debugging
            try {
                sys.io.File.saveContent("catalog_response.json", data);
                Logger.debug('HCLDownloader: Saved catalog response to catalog_response.json (threaded)');
            } catch (e:Dynamic) {
                Logger.error('HCLDownloader: Failed to save catalog response to file (threaded): ${e}');
            }
            
            // Parse JSON
            var catalogJson:Dynamic;
            try {
                catalogJson = haxe.Json.parse(data);
                Logger.debug('HCLDownloader: Parsed catalog JSON successfully (threaded)');
            } catch (e:Dynamic) {
                triggerError('Failed to parse catalog: ${e}');
                return;
            }
            
            // Find the file ID by name
            var fileId = findFileIdByName(catalogJson, _currentFile.originalFilename);
            if (fileId != null) {
                Logger.info('HCLDownloader: Found file ID in catalog (threaded): ${fileId}');
                // Store file ID in sha256 field
                _currentFile.sha256 = fileId;
                getDownloadUrlThreaded();
            } else {
                triggerError('Failed to find file ID for ${_currentFile.originalFilename} in catalog');
            }
        };
        
        // Add callback for error
        http.onError = function(error:String) {
            Logger.error('HCLDownloader: Catalog request failed with error (threaded): ${error}');
            triggerError('Failed to fetch catalog: ${error}');
        };
        
        // Send the request
        try {
            Logger.debug('HCLDownloader: Sending catalog request to ${MYHCL_CATALOG_URL} (threaded)');
            http.request(false); // false = GET request
        } catch (e:Dynamic) {
            Logger.error('HCLDownloader: Failed to send catalog request (threaded): ${e}');
            triggerError('Failed to send catalog request: ${e}');
        }
    }
    
    /**
     * Threaded version of getDownloadUrl
     */
    private function getDownloadUrlThreaded():Void {
        // Update current step
        _currentStep = HCLDownloadStep.GettingDownloadURL;
        
        Logger.info('HCLDownloader: Getting download URL for file ID (threaded): ${_currentFile.sha256}');
        
        // Reset redirect tracking
        _followingRedirects = false;
        _finalRedirectUrl = null;
        
        // Construct the download URL using the file ID
        var downloadUrl = MYHCL_DOWNLOAD_URL_PREFIX + _currentFile.sha256 + MYHCL_DOWNLOAD_URL_SUFFIX;
        Logger.debug('HCLDownloader: Requesting download URL from (threaded): ${downloadUrl}');
        
        // Start following redirects from this URL
        _followingRedirects = true;
        getUrlWithRedirectsThreaded(downloadUrl);
    }
    
    /**
     * Threaded version of getUrlWithRedirects
     * This non-recursive implementation handles redirects one at a time in the worker thread
     */
    private function getUrlWithRedirectsThreaded(url:String):Void {
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
                
                Logger.debug('HCLDownloader: Received response from URL (threaded): ${currentUrl}');
                
                // Save response to a file for debugging
                if (redirectCount == 0) { // Only save the first response
                    try {
                        sys.io.File.saveContent("download_url_response.json", data);
                        Logger.debug('HCLDownloader: Saved download URL response to download_url_response.json (threaded)');
                    } catch (e:Dynamic) {
                        Logger.error('HCLDownloader: Failed to save download URL response to file (threaded): ${e}');
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
                    Logger.debug('HCLDownloader: Got download URL from response (threaded): ${_finalRedirectUrl}');
                    // Always route back to main thread for downloading
                // Send the message to start download on main thread
                if (_communicator == null) {
                    _communicator = ThreadCommunicator.getInstance();
                }
                
                // Post message to main thread to start download
                _communicator.postThreadMessage("start_download", {
                    url: _finalRedirectUrl,
                    tempFilePath: _tempFilePath,
                    file: _currentFile
                });
                
                // Set up listener on main thread if not already done
                _setupMainThreadDownloadListener();
                    return;
                }
                
                // If we got here, but the response is empty or not a URL,
                // assume the current URL is the final one
                _finalRedirectUrl = currentUrl;
                Logger.debug('HCLDownloader: Using current URL as download URL (threaded): ${_finalRedirectUrl}');
                
                // Always route back to main thread for downloading
                if (_communicator == null) {
                    _communicator = ThreadCommunicator.getInstance();
                }
                
                // Post message to main thread to start download
                _communicator.postThreadMessage("start_download", {
                    url: _finalRedirectUrl,
                    tempFilePath: _tempFilePath,
                    file: _currentFile
                });
                
                // Set up listener on main thread if not already done
                _setupMainThreadDownloadListener();
            };

            http.onStatus = function(status:Int) {
                Logger.debug('HCLDownloader: HTTP Status for ${currentUrl} (threaded): ${status}');
                
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
                        Logger.debug('HCLDownloader: Redirecting to (threaded): ${location}');
                        // Update for next redirect
                        currentUrl = location;
                        redirectCount++;
                        processUrl(); // Process the next URL in the chain
                    } else {
                        Logger.error('HCLDownloader: No Location header found for redirect status (threaded) ${status}');
                        _followingRedirects = false;
                        triggerError('Failed to get download URL: No Location header in redirect response');
                    }
                }
                // No special cases for other status codes like 403 - we MUST follow the redirects
            };

            http.onError = function(error:String) {
                if (!_followingRedirects) return; // Chain was already completed
                
                Logger.error('HCLDownloader: Error requesting ${currentUrl} (threaded): ${error}');
                
                // Always treat errors as fatal - no fallbacks
                _followingRedirects = false;
                triggerError('Failed to get download URL: ${error}');
            };

            try {
                Logger.debug('HCLDownloader: Making request to ${currentUrl} (redirect #${redirectCount}, threaded)');
                http.request(false); // false = GET request
            } catch (e:Dynamic) {
                Logger.error('HCLDownloader: Exception making request to ${currentUrl} (threaded): ${e}');
                _followingRedirects = false;
                triggerError('Failed to send download URL request: ${e}');
            }
        }
        
        // Start the chain
        processUrl();
    }
    
    /**
     * Threaded version of startDownload
     */
    private function startDownloadThreaded():Void {
        if (!_followingRedirects) return; // Another download already started
        
        // Mark as no longer following redirects to avoid multiple downloads
        _followingRedirects = false;
        
        // Set the download URL and start the download
        _downloadUrl = _finalRedirectUrl;
        
        // We need to return to the main thread for URLStream operations
        // The error "Call run() only from the main thread" indicates URLStream must be used on main thread
        if (_communicator == null) {
            _communicator = ThreadCommunicator.getInstance();
        }
        
        // Post message to main thread to start download
        _communicator.postThreadMessage("start_download", {
            url: _downloadUrl,
            tempFilePath: _tempFilePath,
            file: _currentFile
        });
        
        // Set up listener on main thread if not already done
        _setupMainThreadDownloadListener();
    }
    
    /**
     * Set up listener for download operations on the main thread
     */
    private var _mainThreadDownloadListenerAdded:Bool = false;
    private function _setupMainThreadDownloadListener():Void {
        if (_mainThreadDownloadListenerAdded) return;
        
        if (_communicator == null) {
            _communicator = ThreadCommunicator.getInstance();
        }
        
        // Add listener for download start messages - runs on main thread
        _communicator.addEventListener("start_download", function(e:ThreadMessageEvent) {
            var data = e.messageData;
            if (data != null && data.url != null) {
                // Store values from message
                _downloadUrl = data.url;
                if (data.tempFilePath != null) {
                    _tempFilePath = data.tempFilePath;
                }
                
                Logger.debug('HCLDownloader: Starting download on main thread from: ${_downloadUrl}');
                
                // Call the main thread download method which uses URLStream
                // This now runs on the main thread
                downloadFileMainThread();
            }
        });
        
        _mainThreadDownloadListenerAdded = true;
    }
    
    // Thread and mutex for general thread synchronization
    private var _mutex:Mutex;
    private var _progressMutex:Mutex;
    private var _thread:Thread;
    
    // Thread and mutex for file access during verification
    private var _verificationMutex:Mutex;
    private var _verificationThread:Thread;
    
    // Thread communicator for message passing between threads
    private var _communicator:ThreadCommunicator;
    
    // Event listener flags to avoid duplicate listeners
    private var _tokenUpdateListenerAdded:Bool = false;
    private var _progressUpdateListenerAdded:Bool = false;
    
    /**
     * Set up token update listener (one time setup)
     */
    private function _setupTokenUpdateListener():Void {
        if (_tokenUpdateListenerAdded) return;
        
        // Get communicator instance
        if (_communicator == null) {
            _communicator = ThreadCommunicator.getInstance();
        }
        
        // Add listener for token update messages
        _communicator.addEventListener("token_update", function(e:ThreadMessageEvent) {
            var data = e.messageData;
            if (data != null && data.tokenName != null && data.newToken != null) {
                updateHCLToken(data.tokenName, data.newToken);
                Logger.info('HCLDownloader: Updated rotated refresh token in secrets (from thread message)');
            }
        });
        
        _tokenUpdateListenerAdded = true;
    }
    
    /**
     * Set up access token update listener (one time setup)
     * This handles updating both refresh and access tokens together
     */
    private var _accessTokenUpdateListenerAdded:Bool = false;
    private function _setupAccessTokenUpdateListener():Void {
        if (_accessTokenUpdateListenerAdded) return;
        
        // Get communicator instance
        if (_communicator == null) {
            _communicator = ThreadCommunicator.getInstance();
        }
        
        // Add listener for token update messages that include access token
        _communicator.addEventListener("token_update_with_access", function(e:ThreadMessageEvent) {
            var data = e.messageData;
            if (data != null && data.tokenName != null && data.newToken != null && data.accessToken != null) {
                // Update both refresh token and access token together
                updateHCLToken(data.tokenName, data.newToken, data.accessToken);
                Logger.info('HCLDownloader: Updated both refresh token and access token in secrets (from thread message)');
            }
        });
        
        _accessTokenUpdateListenerAdded = true;
    }
    
    /**
     * Set up progress update listener (one time setup)
     */
    private function _setupProgressUpdateListener():Void {
        if (_progressUpdateListenerAdded) return;
        
        // Get communicator instance
        if (_communicator == null) {
            _communicator = ThreadCommunicator.getInstance();
        }
        
        // Add listener for progress update messages
        _communicator.addEventListener("download_progress", function(e:ThreadMessageEvent) {
            var data = e.messageData;
            if (data != null && data.file != null && data.progress != null) {
                Logger.debug('HCLDownloader: Download progress (from thread): ${Math.round(data.progress * 100)}% (${data.bytesLoaded}/${data.bytesTotal} bytes)');
                for (f in _onDownloadProgress) f(this, data.file, data.progress);
            }
        });
        
        _progressUpdateListenerAdded = true;
    }
    
    /**
     * Threaded version of downloadFile
     */
    private function downloadFileThreaded():Void {
        throw new Error("This function should never be called directly - should only be dispatched via main thread");
    }
    
    /**
     * Main thread download method - called via thread message
     */
    private function downloadFileMainThread():Void {
        // Update current step
        _currentStep = HCLDownloadStep.Downloading;
        
        // Create URL request for file download
        var downloadRequest = new URLRequest(_downloadUrl);
        downloadRequest.requestHeaders = [
            new URLRequestHeader("Authorization", "Bearer " + _accessToken),
            new URLRequestHeader("User-Agent", "curl/7.68.0") // Match curl's user agent
        ];
        
        try {
            // Create and open file output for writing
            try {
                Logger.debug('HCLDownloader: Opening output file (threaded): ${_tempFilePath}');
                _fileOutput = sys.io.File.write(_tempFilePath, true);
            } catch (e:Dynamic) {
                triggerError('Failed to open output file: ${e}');
                return;
            }
            
            // Create URLStream for efficient streaming
            _urlStream = new URLStream();
            
            // Set up event listeners
            _urlStream.addEventListener(Event.OPEN, function(e:Event):Void {
                Logger.debug('HCLDownloader: Download connection opened (threaded)');
            });
            
            _urlStream.addEventListener(ProgressEvent.PROGRESS, function(e:ProgressEvent):Void {
                // Thread-safe update of progress data
                _progressMutex.acquire();
                
                // Store total bytes for the download
                _downloadBytesTotal = Std.int(e.bytesTotal);
                
                // Calculate progress percentage
                var progress:Float = 0;
                if (e.bytesTotal > 0) {
                    progress = e.bytesLoaded / e.bytesTotal;
                }
                _progressMutex.release();
                
                // Post progress event to UI thread using our thread communication system
                if (_communicator != null) {
                    _communicator.postThreadMessage("download_progress", {
                        bytesLoaded: e.bytesLoaded,
                        bytesTotal: e.bytesTotal,
                        progress: progress,
                        file: _currentFile
                    });
                }
                
                // Setup listener for progress updates if not already done
                _setupProgressUpdateListener();
                
                // Process available bytes in the stream
                processAvailableBytes();
            });
            
            _urlStream.addEventListener(Event.COMPLETE, function(e:Event):Void {
                Logger.info('HCLDownloader: Download stream complete (threaded)');
                
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
                    Logger.error('HCLDownloader: Error closing output file (threaded): ${e}');
                }
                
                // Clean up stream
                cleanupUrlStream();
                
                // Need to ensure the file is fully written before verification
                // Add a small delay to allow file system operations to complete
                Logger.debug('HCLDownloader: File downloaded, ensuring file handle is properly closed before verification');
                
                // Use a timer to create a short delay before verification
                // This helps avoid race conditions with file handles
                var verificationTimer = new haxe.Timer(500); // 500ms delay
                verificationTimer.run = function() {
                    verificationTimer.stop();
                    verificationTimer = null;
                    
                    // Now verify the downloaded file - this will move to the next step
                    verifyFileHashThreaded();
                };
            });
            
            _urlStream.addEventListener(IOErrorEvent.IO_ERROR, function(e:IOErrorEvent):Void {
                Logger.error('HCLDownloader: Download error (threaded): ${e.text}, ID: ${e.errorID}');
                
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
                    Logger.error('HCLDownloader: Error details (threaded): ${errorDetails}');
                }
                
                // Close the output file
                try {
                    if (_fileOutput != null) {
                        _fileOutput.close();
                        _fileOutput = null;
                    }
                } catch (e:Dynamic) {
                    Logger.error('HCLDownloader: Error closing output file (threaded): ${e}');
                }
                
                cleanupUrlStream();
                triggerError('Failed to download file: ${e.text}');
            });
            
            // Start the download
            Logger.debug('HCLDownloader: Starting file download from (threaded) ${_downloadUrl}');
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
        
        // Update current step with progress reporting
        updateStep(HCLDownloadStep.GettingAccessToken);
        
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
            updateStep(HCLDownloadStep.ReceivedTokenResponse);
            Logger.debug('HCLDownloader: Received token response');
            
            // Process response - similar to _accessTokenLoaderComplete
            var responseJson:Dynamic;
            try {
                responseJson = haxe.Json.parse(data);
                updateStep(HCLDownloadStep.ParsingTokenJSON);
                Logger.debug('HCLDownloader: Parsed JSON response successfully');
            } catch (e:Dynamic) {
                triggerError('Failed to parse token response: ${e}');
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
                updateStep(HCLDownloadStep.FoundAccessToken);
                Logger.debug('HCLDownloader: Found access_token field in response');
            } 
            // Try HCL specific field if standard not found
            else if (Reflect.hasField(responseJson, "accessToken")) {
                accessToken = Reflect.field(responseJson, "accessToken");
                updateStep(HCLDownloadStep.FoundAccessToken);
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
                
                // Log for debugging
                Logger.error('HCLDownloader: Token error: ${errorMessage}');
                triggerError('Failed to get access token: ${errorMessage}');
                return;
            }
            
            Logger.info('HCLDownloader: Successfully obtained fresh access token');
            updateStep(HCLDownloadStep.ObtainedAccessToken);
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
        
        updateStep(HCLDownloadStep.SendingTokenRequest);
        
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
                // Store file ID in sha256 field
                _currentFile.sha256 = fileId;
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
        
        Logger.info('HCLDownloader: Getting download URL for file ID: ${_currentFile.sha256}');
        
        // Reset redirect tracking
        _followingRedirects = false;
        _finalRedirectUrl = null;
        
        // Construct the download URL using the file ID
        var downloadUrl = MYHCL_DOWNLOAD_URL_PREFIX + _currentFile.sha256 + MYHCL_DOWNLOAD_URL_SUFFIX;
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
     * Step 4: Verify the file hash in a thread
     * This is a threaded implementation that runs verification in a separate thread
     */
    private function verifyFileHashThreaded():Void {
        // Safety check - this can happen during multiple async operations
        if (_currentFile == null) {
            Logger.error('HCLDownloader: Cannot verify file hash - current file is null');
            cleanupTempFiles();
            return;
        }
        
        if (_tempFilePath == null || !FileSystem.exists(_tempFilePath)) {
            Logger.error('HCLDownloader: Cannot verify file hash - temp file does not exist: ${_tempFilePath}');
            cleanupTempFiles();
            return;
        }
        
        // Update current step with clear message about verification
        updateStep(HCLDownloadStep.VerifyingHash);
        
        Logger.info('HCLDownloader: Starting SHA256 verification (threaded)');
        
        // Post progress event with verification status
        if (_communicator != null) {
            _communicator.postThreadMessage("verification_progress", {
                file: _currentFile,
                message: "Starting SHA256 verification...",
                progress: 0.0
            });
        }
        
        // Get communicator instance if needed
        if (_communicator == null) {
            _communicator = ThreadCommunicator.getInstance();
        }
        
        // Set up listener for verification progress if not already done
        _setupVerificationListener();
        
        try {
            // Check if we have a SHA256 hash for verification
            if (_currentFile.sha256 != null) {
                Logger.info('HCLDownloader: Verifying with SHA256 hash (threaded)');
                
                // Post progress update
                _communicator.postThreadMessage("verification_progress", {
                    file: _currentFile,
                    message: "Calculating file checksum...",
                    progress: 0.2
                });
                
                // Store file reference locally to prevent null reference if cleanup occurs elsewhere
                var fileRef = _currentFile;
                var tempPathRef = _tempFilePath;
                
                // Calculate SHA256 hash asynchronously
                SuperHumanHashes.calculateSHA256Async(tempPathRef, function(calculatedSha256:String) {
                    // Safe null checks for all variables
                    if (calculatedSha256 == null || fileRef == null) {
                        Logger.error('SHA256 verification failed: calculatedSha256=${calculatedSha256 != null}, fileRef=${fileRef != null}');
                        // Post verification failure if possible
                        if (_communicator != null) {
                            _communicator.postThreadMessage("verification_failed", {
                                message: 'SHA256 verification failed: null reference'
                            });
                        }
                        // Clean up if possible
                        cleanupTempFiles();
                        return;
                    }
                    
                    calculatedSha256 = calculatedSha256.toLowerCase();
                    
                    // Safely handle the case where sha256 might be null
                    if (fileRef.sha256 == null) {
                        Logger.error('SHA256 verification failed: no expected hash value in file reference');
                        if (_communicator != null) {
                            _communicator.postThreadMessage("verification_failed", {
                                message: 'SHA256 verification failed: no expected hash value'
                            });
                        }
                        cleanupTempFiles();
                        return;
                    }
                    
                    var expectedSha256 = fileRef.sha256.toLowerCase();
                    
                    // Post progress update for hash comparison
                    _communicator.postThreadMessage("verification_progress", {
                        file: _currentFile,
                        message: "Comparing file checksum...",
                        progress: 0.8
                    });
                    
                    if (calculatedSha256 != expectedSha256) {
                        Logger.error('SHA256 hash verification failed. Expected: ${expectedSha256}, Got: ${calculatedSha256}');
                        
                        // Post verification failure
                        _communicator.postThreadMessage("verification_failed", {
                            file: _currentFile,
                            message: 'SHA256 hash verification failed. Expected: ${expectedSha256}, Got: ${calculatedSha256}'
                        });
                        
                        triggerError('SHA256 hash verification failed. Expected: ${expectedSha256}, Got: ${calculatedSha256}');
                        cleanupTempFiles();
                        return;
                    }
                    
                    // Post progress update for successful verification
                    _communicator.postThreadMessage("verification_progress", {
                        file: _currentFile,
                        message: "SHA256 verification successful!",
                        progress: 1.0
                    });
                    
                    Logger.info('SHA256 hash verification successful (threaded): ${calculatedSha256}');
                    finalizeDownload();
                });
                
                // Don't proceed further here - wait for the async callback
                return;
            }
            
            // If we got here, we don't have a SHA256 hash to verify against
            // This typically happens when using file IDs instead of hashes
            Logger.warning('HCLDownloader: Skipping hash verification - no SHA256 hash available (threaded)');
            
            // Post message about skipping verification
            _communicator.postThreadMessage("verification_progress", {
                file: _currentFile,
                message: "Skipping hash verification (no SHA256 hash available)",
                progress: 1.0
            });
            
            finalizeDownload();
            
        } catch (e:Dynamic) {
            Logger.error('Exception during hash verification (threaded): ${e}');
            
            // Post verification failure
            _communicator.postThreadMessage("verification_failed", {
                file: _currentFile,
                message: 'Exception during hash verification: ${e}'
            });
            
            triggerError('Exception during hash verification: ${e}');
            cleanupTempFiles();
        }
    }
    
    /**
     * Set up verification listener (one time setup)
     */
    private var _verificationListenerAdded:Bool = false;
    private function _setupVerificationListener():Void {
        if (_verificationListenerAdded) return;
        
        // Get communicator instance
        if (_communicator == null) {
            _communicator = ThreadCommunicator.getInstance();
        }
        
        // Add listener for verification progress messages
        _communicator.addEventListener("verification_progress", function(e:ThreadMessageEvent) {
            var data = e.messageData;
            if (data != null && data.file != null) {
                Logger.debug('HCLDownloader: Verification progress: ${data.message}');
                // Update the UI with the verification progress
                updateStep(HCLDownloadStep.VerifyingHash, data.progress);
            }
        });
        
        // Add listener for verification failure messages
        _communicator.addEventListener("verification_failed", function(e:ThreadMessageEvent) {
            var data = e.messageData;
            if (data != null && data.message != null) {
                Logger.error('HCLDownloader: Verification failed: ${data.message}');
            }
        });
        
        _verificationListenerAdded = true;
    }
    
    /**
     * Legacy method for compatibility
     */
    private function verifyFileHash():Void {
        // Just delegate to the threaded implementation
        verifyFileHashThreaded();
    }

    /**
     * Final step: Move file to cache
     */
    private function finalizeDownload():Void {
        // Null safety check - this can happen during multiple async operations completing
        if (_currentFile == null) {
            Logger.error('HCLDownloader: Cannot finalize download - current file is null');
            cleanupTempFiles();
            return;
        }
        
        // Update current step
        updateStep(HCLDownloadStep.MovingFile);
        
        // Get target path from file cache
        var targetPath = _currentFile.path;
        if (targetPath == null) {
            Logger.error('HCLDownloader: Cannot finalize download - target path is null');
            cleanupTempFiles();
            return;
        }
        
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
        
        // Check if we need to move the file (we don't if _tempFilePath is already the target path)
        if (_tempFilePath != targetPath) {
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
        } else {
            // File was already downloaded to the target path - no move needed
            Logger.info('HCLDownloader: File already at target path, no move needed: ${targetPath}');
        }
        
        // Update file exists flag
        _currentFile.exists = true;
        
        // Clean up temporary JSON files
        cleanupJsonFiles();
        
        // Set current step to complete
        updateStep(HCLDownloadStep.Complete);
        
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
     * Clean up temporary JSON files created during download
     */
    private function cleanupJsonFiles():Void {
        // Define the list of temporary JSON files to clean up
        var jsonFiles = [
            "token_request.json",
            "catalog_response.json",
            "download_url_response.json"
        ];
        
        // Iterate through each file and delete if it exists
        for (jsonFile in jsonFiles) {
            if (FileSystem.exists(jsonFile)) {
                try {
                    Logger.debug('HCLDownloader: Cleaning up temporary JSON file: ${jsonFile}');
                    FileSystem.deleteFile(jsonFile);
                } catch (e:Dynamic) {
                    Logger.warning('Failed to delete temporary JSON file ${jsonFile}: ${e}');
                }
            }
        }
    }
    
    /**
     * Trigger error event
     */
    private function triggerError(message:String):Void {
        // Update current step
        _currentStep = HCLDownloadStep.Error;
        
        // Check for specific error conditions and provide helpful messages
        var enhancedMessage = message;
        
        // Check for 403 errors and add appropriate context depending on which stage we're in
        if (message.toLowerCase().indexOf("403") >= 0 || 
            message.toLowerCase().indexOf("forbidden") >= 0 ||
            message.toLowerCase().indexOf("not authorized") >= 0) {
            
            // Differentiate between token errors and download errors
            if (_currentStep == HCLDownloadStep.GettingAccessToken || 
                _currentStep == HCLDownloadStep.SendingTokenRequest || 
                _currentStep == HCLDownloadStep.ReceivedTokenResponse || 
                _currentStep == HCLDownloadStep.ParsingTokenJSON) {
                
                // Authentication-related 403 error
                enhancedMessage = message + "\n\nAPI key has likely expired." +
                                 "\nPlease generate a new API key at https://my.hcltechsw.com/";
            } else {
                // Download-related 403 error - likely EULA issue
                enhancedMessage = message + "\n\nYou may need to accept the EULA in the HCL Software Portal." +
                                 "\nPlease visit: https://my.hcltechsw.com/ and log in to accept the license agreement.";
            }
        }
        
        Logger.error('HCLDownloader: ${enhancedMessage}');
        
        // Store current file before cleanup for event
        var currentFile = _currentFile;
        
        // Clean up resources
        cleanupTempFiles();
        cleanupJsonFiles(); // Clean up temporary JSON files
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
        for (f in _onDownloadError) f(this, currentFile, enhancedMessage);
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
        
        // Get target path from file cache
        var targetPath = file.path;
        
        // Check if file already exists at the target path
        if (FileSystem.exists(targetPath)) {
            // File exists - use temporary path with .download extension
            var cacheDir = SuperHumanFileCache.getCacheDirectory();
            _tempFilePath = cacheDir + "/" + file.originalFilename + ".download";
            Logger.info('HCLDownloader: File already exists at target path, using temp file: ${_tempFilePath}');
        } else {
            // File does not exist - download directly to target path
            _tempFilePath = targetPath;
            
            // Ensure target directory exists
            var targetDir = haxe.io.Path.directory(targetPath);
            if (!FileSystem.exists(targetDir)) {
                try {
                    FileSystem.createDirectory(targetDir);
                } catch (e:Dynamic) {
                    triggerError('Failed to create target directory: ${e}');
                    return;
                }
            }
            
            Logger.info('HCLDownloader: File missing, downloading directly to: ${_tempFilePath}');
        }
        
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
 * Progress mapping to map steps to specific percentages
 */
class ProgressRangeMap {
    // Maps download steps to exact percentage points
    private static final ranges = [
        // Initial steps: 1-19%
        HCLDownloadStep.GettingAccessToken => { min: 1.0, max: 1.0 },
        HCLDownloadStep.SavingTokenRequest => { min: 2.0, max: 2.0 },
        HCLDownloadStep.SendingTokenRequest => { min: 3.0, max: 3.0 },
        HCLDownloadStep.ReceivedTokenResponse => { min: 4.0, max: 4.0 },
        HCLDownloadStep.SavingTokenResponse => { min: 5.0, max: 5.0 },
        HCLDownloadStep.ParsingTokenJSON => { min: 6.0, max: 6.0 },
        HCLDownloadStep.FoundAccessToken => { min: 7.0, max: 7.0 },
        HCLDownloadStep.ObtainedAccessToken => { min: 8.0, max: 8.0 },
        
        HCLDownloadStep.FetchingCatalog => { min: 9.0, max: 9.0 },
        HCLDownloadStep.SendingCatalogRequest => { min: 10.0, max: 10.0 },
        HCLDownloadStep.ReceivedCatalogResponse => { min: 11.0, max: 11.0 },
        HCLDownloadStep.SavingCatalogResponse => { min: 12.0, max: 12.0 },
        HCLDownloadStep.ParsingCatalogJSON => { min: 13.0, max: 13.0 },
        
        HCLDownloadStep.SearchingFile => { min: 14.0, max: 14.0 },
        HCLDownloadStep.CatalogParsed => { min: 15.0, max: 15.0 },
        HCLDownloadStep.FindingFile => { min: 16.0, max: 16.0 },
        HCLDownloadStep.FoundFileID => { min: 17.0, max: 17.0 },
        
        HCLDownloadStep.GettingDownloadURL => { min: 18.0, max: 18.0 },
        HCLDownloadStep.RequestingDownloadURL => { min: 19.0, max: 19.0 },
        
        // Download progress (20-75%)
        HCLDownloadStep.Downloading => { min: 20.0, max: 75.0 },
        
        // Final steps
        HCLDownloadStep.WritingFile => { min: 75.0, max: 90.0 },
        HCLDownloadStep.VerifyingHash => { min: 90.0, max: 95.0 },
        HCLDownloadStep.MovingFile => { min: 95.0, max: 99.0 },
        HCLDownloadStep.Complete => { min: 100.0, max: 100.0 }
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
        
        // Special case for downloading: subProgress represents actual download progress
        // which we want to scale over the 20%-75% range
        if (step == HCLDownloadStep.Downloading) {
            // Scale from 20 to 75 percent (55% of the bar)
            return 20.0 + (subProgress * 55.0);
        }
        
        // For all other steps, just use the exact percentage defined
        // Each step represents a specific percentage point in the progress
        return range.min;
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
