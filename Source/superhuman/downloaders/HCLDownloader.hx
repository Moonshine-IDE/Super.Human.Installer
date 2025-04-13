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
import prominic.sys.io.AbstractExecutor;
import prominic.sys.io.Executor;
import prominic.sys.io.ExecutorManager;
import superhuman.config.SuperHumanSecrets;
import superhuman.server.cache.SuperHumanCachedFile;
import superhuman.server.cache.SuperHumanFileCache;
import superhuman.config.SuperHumanHashes;
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
    private static final MYHCL_TOKEN_URL:String = "https://api.hcltechsw.com/auth/realms/HCL/protocol/openid-connect/token";
    private static final MYHCL_DOWNLOAD_URL_PREFIX:String = "https://api.hcltechsw.com/filesystem/v1/files/";
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
    var _tempResponsePath:String;

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
    private function new() {
        _onDownloadStart = new ChainedList(this);
        _onDownloadProgress = new ChainedList(this);
        _onDownloadComplete = new ChainedList(this);
        _onDownloadError = new ChainedList(this);
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
        
        // Notify download is starting
        for (f in _onDownloadStart) f(this, file);
        
        // Create temp file paths
        var cacheDir = SuperHumanFileCache.getCacheDirectory();
        _tempFilePath = cacheDir + "/" + file.originalFilename + ".download";
        _tempResponsePath = cacheDir + "/response.json";
        
        // Start the download process by getting access token
        getAccessToken(token);
    }

    /**
     * Get HCL token from secrets
     */
    private function getHCLToken(tokenName:String):String {
        var secrets = SuperHumanInstaller.getInstance().config.secrets;
        if (secrets == null || secrets.hcl_download_portal_api_keys == null) return null;
        
        for (key in secrets.hcl_download_portal_api_keys) {
            if (key.name == tokenName) {
                return key.key;
            }
        }
        
        return null;
    }

    /**
     * Get list of available HCL tokens
     */
    public function getAvailableHCLTokens():Array<{name:String, key:String}> {
        var result:Array<{name:String, key:String}> = [];
        var secrets = SuperHumanInstaller.getInstance().config.secrets;
        
        if (secrets == null || secrets.hcl_download_portal_api_keys == null) return result;
        
        for (key in secrets.hcl_download_portal_api_keys) {
            result.push({name: key.name, key: key.key});
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
        
        for (resource in secrets.custom_resource_url) {
            result.push({name: resource.name, url: resource.url});
        }
        
        return result;
    }

    /**
     * Step 1: Get access token from refresh token
     * @param refreshToken The refresh token to use
     */
    private function getAccessToken(refreshToken:String):Void {
        if (ExecutorManager.getInstance().exists(HCLDownloaderContext.GetAccessToken)) {
            return;
        }
        
        Logger.info('HCLDownloader: Getting access token from refresh token');
        
        // Create JSON payload for token request
        var jsonPayload = '{\"refreshToken\":\"' + refreshToken + '\"}';
        var tempJsonPath = haxe.io.Path.join([Sys.getCwd(), "temp_token_request.json"]);
        try {
            File.saveContent(tempJsonPath, jsonPayload);
        } catch (e:Dynamic) {
            triggerError('Failed to create temporary JSON file: ${e}');
            return;
        }
        
        // Prepare curl command to exchange refresh token for access token
        var executor = new Executor(
            #if windows "curl.exe" #else "curl" #end,
            [
                "-sL", 
                MYHCL_TOKEN_URL,
                "-H", "Content-Type: application/json",
                "-d", "@" + tempJsonPath,
                "-o", _tempResponsePath
            ]
        );
        
        executor.onStop.add(_accessTokenExecutorStopped);
        ExecutorManager.getInstance().set(HCLDownloaderContext.GetAccessToken, executor);
        executor.execute();
    }

    /**
     * Handle access token response
     */
    private function _accessTokenExecutorStopped(executor:AbstractExecutor):Void {
        ExecutorManager.getInstance().remove(HCLDownloaderContext.GetAccessToken);
        executor.dispose();
        
        // Delete temporary request file
        var tempJsonPath = haxe.io.Path.join([Sys.getCwd(), "temp_token_request.json"]);
        if (FileSystem.exists(tempJsonPath)) {
            try {
                FileSystem.deleteFile(tempJsonPath);
            } catch (e:Dynamic) {
                Logger.warning('Failed to delete temporary JSON file: ${e}');
            }
        }
        
        // Check for response file
        if (!FileSystem.exists(_tempResponsePath)) {
            triggerError("Failed to get access token: No response received");
            return;
        }
        
        // Parse response
        var responseContent:String;
        try {
            responseContent = File.getContent(_tempResponsePath);
        } catch (e:Dynamic) {
            triggerError('Failed to read token response: ${e}');
            return;
        }
        
        // Parse JSON
        var responseJson:Dynamic;
        try {
            responseJson = haxe.Json.parse(responseContent);
        } catch (e:Dynamic) {
            triggerError('Failed to parse token response: ${e}');
            return;
        }
        
        // Extract access token
        if (responseJson.accessToken == null) {
            var errorMessage = responseJson.summary != null ? responseJson.summary : "Unknown error";
            triggerError('Failed to get access token: ${errorMessage}');
            return;
        }
        
        _accessToken = responseJson.accessToken;
        
        // Delete response file
        try {
            FileSystem.deleteFile(_tempResponsePath);
        } catch (e:Dynamic) {
            Logger.warning('Failed to delete response file: ${e}');
        }
        
        // Continue to next step
        getDownloadUrl();
    }

    /**
     * Step 2: Get download URL for the file
     */
    private function getDownloadUrl():Void {
        if (ExecutorManager.getInstance().exists(HCLDownloaderContext.GetDownloadURL)) {
            return;
        }
        
        Logger.info('HCLDownloader: Getting download URL for file ID: ${_currentFile.hash}');
        
        // Prepare curl command to get download URL
        var executor = new Executor(
            #if windows "curl.exe" #else "curl" #end,
            [
                "-s",
                "--write-out", "%{redirect_url}\\n",
                "--output", _tempResponsePath,
                MYHCL_DOWNLOAD_URL_PREFIX + _currentFile.hash + MYHCL_DOWNLOAD_URL_SUFFIX,
                "-H", "Authorization: Bearer " + _accessToken
            ]
        );
        
        executor.onStop.add(_downloadUrlExecutorStopped);
        executor.onStdOut.add(_downloadUrlExecutorStdOut);
        ExecutorManager.getInstance().set(HCLDownloaderContext.GetDownloadURL, executor);
        executor.execute();
    }

    private var _downloadUrl:String;
    
    /**
     * Handle download URL response stdout
     */
    private function _downloadUrlExecutorStdOut(executor:AbstractExecutor, data:String):Void {
        if (data != null && data.length > 0) {
            _downloadUrl = StringTools.trim(data);
        }
    }

    /**
     * Handle download URL executor completed
     */
    private function _downloadUrlExecutorStopped(executor:AbstractExecutor):Void {
        ExecutorManager.getInstance().remove(HCLDownloaderContext.GetDownloadURL);
        executor.dispose();
        
        // Check for download URL
        if (_downloadUrl == null || _downloadUrl.length == 0) {
            // Check for error response
            if (FileSystem.exists(_tempResponsePath)) {
                try {
                    var responseContent = File.getContent(_tempResponsePath);
                    var responseJson:Dynamic = null;
                    try {
                        responseJson = haxe.Json.parse(responseContent);
                    } catch (e:Dynamic) {
                        Logger.warning('Failed to parse error response: ${e}');
                    }
                    
                    if (responseJson != null && responseJson.summary != null) {
                        triggerError('Failed to get download URL: ${responseJson.summary}');
                    } else {
                        triggerError("Failed to get download URL: Unknown error");
                    }
                } catch (e:Dynamic) {
                    triggerError('Failed to read error response: ${e}');
                }
                
                try {
                    FileSystem.deleteFile(_tempResponsePath);
                } catch (e:Dynamic) {
                    Logger.warning('Failed to delete response file: ${e}');
                }
                return;
            }
            
            triggerError("Failed to get download URL: No redirect URL received");
            return;
        }
        
        // Continue to next step
        downloadFile();
    }

    /**
     * Step 3: Download the file
     */
    private function downloadFile():Void {
        if (ExecutorManager.getInstance().exists(HCLDownloaderContext.DownloadFile)) {
            return;
        }
        
        Logger.info('HCLDownloader: Downloading file from URL: ${_downloadUrl}');
        
        // Prepare curl command to download file
        var executor = new Executor(
            #if windows "curl.exe" #else "curl" #end,
            [
                "-L",
                _downloadUrl,
                "-w", "%{http_code}",
                "-H", "Authorization: Bearer " + _accessToken,
                "-o", _tempFilePath
            ]
        );
        
        executor.onStop.add(_downloadFileExecutorStopped);
        ExecutorManager.getInstance().set(HCLDownloaderContext.DownloadFile, executor);
        executor.execute();
    }

    /**
     * Handle file download completed
     */
    private function _downloadFileExecutorStopped(executor:AbstractExecutor):Void {
        ExecutorManager.getInstance().remove(HCLDownloaderContext.DownloadFile);
        executor.dispose();
        
        // Check if file was downloaded
        if (!FileSystem.exists(_tempFilePath)) {
            triggerError("Failed to download file: File not found after download");
            return;
        }
        
        // Verify file hash
        verifyFileHash();
    }

    /**
     * Step 4: Verify the file hash
     */
    private function verifyFileHash():Void {
        if (ExecutorManager.getInstance().exists(HCLDownloaderContext.VerifyHash)) {
            return;
        }
        
        Logger.info('HCLDownloader: Verifying file hash');
        
        // Calculate hash based on OS
        var executor:Executor;
        
        #if mac
        executor = new Executor(
            "shasum",
            [
                "-a", "256",
                "-b",
                _tempFilePath
            ]
        );
        #else
        executor = new Executor(
            #if windows "CertUtil.exe" #else "sha256sum" #end,
            #if windows ["-hashfile", _tempFilePath, "SHA256"] #else [_tempFilePath] #end
        );
        #end
        
        executor.onStop.add(_verifyHashExecutorStopped);
        executor.onStdOut.add(_verifyHashExecutorStdOut);
        ExecutorManager.getInstance().set(HCLDownloaderContext.VerifyHash, executor);
        executor.execute();
    }

    private var _fileHash:String;
    
    /**
     * Handle hash calculation stdout
     */
    private function _verifyHashExecutorStdOut(executor:AbstractExecutor, data:String):Void {
        if (data != null && data.length > 0) {
            // Extract hash from output
            #if windows
            // CertUtil format is different, parse the output
            var lines = data.split("\n");
            if (lines.length >= 2) {
                _fileHash = StringTools.trim(lines[1]).toLowerCase();
            }
            #else
            // sha256sum format: [hash] [file]
            var parts = data.split(" ");
            if (parts.length > 0) {
                _fileHash = StringTools.trim(parts[0]).toLowerCase();
            }
            #end
        }
    }

    /**
     * Handle hash verification completed
     */
    private function _verifyHashExecutorStopped(executor:AbstractExecutor):Void {
        ExecutorManager.getInstance().remove(HCLDownloaderContext.VerifyHash);
        executor.dispose();
        
        // Check hash
        if (_fileHash == null || _fileHash.length == 0) {
            triggerError("Failed to verify file hash: No hash calculated");
            cleanupTempFiles();
            return;
        }
        
        // Compare with expected hash (case insensitive)
        var expectedHash = _currentFile.hash.toLowerCase();
        var calculatedHash = _fileHash.toLowerCase();
        
        if (calculatedHash != expectedHash) {
            triggerError('Hash verification failed. Expected: ${expectedHash}, Got: ${calculatedHash}');
            cleanupTempFiles();
            return;
        }
        
        // Hash verified, move file to cache
        finalizeDownload();
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
        
        // Move temp file to target path
        try {
            if (FileSystem.exists(targetPath)) {
                FileSystem.deleteFile(targetPath);
            }
            FileSystem.rename(_tempFilePath, targetPath);
        } catch (e:Dynamic) {
            triggerError('Failed to move downloaded file to cache: ${e}');
            cleanupTempFiles();
            return;
        }
        
        // Update file exists flag
        _currentFile.exists = true;
        
        // Trigger download complete
        for (f in _onDownloadComplete) f(this, _currentFile, true);
        
        // Clean up
        _currentFile = null;
        _accessToken = null;
        _downloadUrl = null;
        _fileHash = null;
    }

    /**
     * Clean up any temporary files
     */
    private function cleanupTempFiles():Void {
        if (_tempFilePath != null && FileSystem.exists(_tempFilePath)) {
            try {
                FileSystem.deleteFile(_tempFilePath);
            } catch (e:Dynamic) {
                Logger.warning('Failed to delete temporary file: ${e}');
            }
        }
        
        if (_tempResponsePath != null && FileSystem.exists(_tempResponsePath)) {
            try {
                FileSystem.deleteFile(_tempResponsePath);
            } catch (e:Dynamic) {
                Logger.warning('Failed to delete response file: ${e}');
            }
        }
    }

    /**
     * Trigger error event
     */
    private function triggerError(message:String):Void {
        Logger.error('HCLDownloader: ${message}');
        for (f in _onDownloadError) f(this, _currentFile, message);
        
        // Clean up
        cleanupTempFiles();
        _currentFile = null;
        _accessToken = null;
        _downloadUrl = null;
        _fileHash = null;
    }

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
     * Get custom resource from secrets
     */
    private function getCustomResource(resourceName:String):{name:String, url:String, useAuth:Bool, user:String, pass:String} {
        var secrets = SuperHumanInstaller.getInstance().config.secrets;
        if (secrets == null || secrets.custom_resource_url == null) return null;
        
        for (resource in secrets.custom_resource_url) {
            if (resource.name == resourceName) {
                return resource;
            }
        }
        
        return null;
    }

    /**
     * Download file from custom URL
     */
    private function downloadFileFromCustomUrl(resource:{name:String, url:String, useAuth:Bool, user:String, pass:String}):Void {
        if (ExecutorManager.getInstance().exists(HCLDownloaderContext.DownloadCustomFile)) {
            return;
        }
        
        Logger.info('HCLDownloader: Downloading file from custom URL: ${resource.url}/${_currentFile.originalFilename}');
        
        // Prepare download URL
        var downloadUrl = resource.url;
        if (downloadUrl.charAt(downloadUrl.length - 1) != "/") downloadUrl += "/";
        downloadUrl += _currentFile.originalFilename;
        
        // Prepare curl command
        var args = ["-L", downloadUrl, "-o", _tempFilePath];
        
        // Add authentication if needed
        if (resource.useAuth && resource.user != null && resource.user.length > 0) {
            args.push("--user");
            args.push(resource.user + ":" + resource.pass);
        }
        
        var executor = new Executor(
            #if windows "curl.exe" #else "curl" #end,
            args
        );
        
        executor.onStop.add(_customDownloadExecutorStopped);
        ExecutorManager.getInstance().set(HCLDownloaderContext.DownloadCustomFile, executor);
        executor.execute();
    }

    /**
     * Handle custom download completed
     */
    private function _customDownloadExecutorStopped(executor:AbstractExecutor):Void {
        ExecutorManager.getInstance().remove(HCLDownloaderContext.DownloadCustomFile);
        executor.dispose();
        
        // Check if file was downloaded
        if (!FileSystem.exists(_tempFilePath)) {
            triggerError("Failed to download file from custom URL: File not found after download");
            return;
        }
        
        // Verify file hash (same as HCL download)
        verifyFileHash();
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
