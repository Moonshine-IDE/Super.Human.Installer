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

package superhuman.utils;

import champaign.core.logging.Logger;
import haxe.io.Bytes;
import haxe.io.BytesOutput;
import haxe.io.Path;
import haxe.zip.Entry;
import haxe.zip.Writer;
import lime.system.System;
import openfl.system.Capabilities;
import superhuman.server.Server;
import sys.FileSystem;
import sys.io.File;

/**
 * Utility for collecting debug information and packaging it for support submissions
 * Handles both application crashes and server provisioning failures
 */
class DebugCollector {
    
    /**
     * Collect debug information for an application crash
     * @param username User's name for the report
     * @param email User's email for the report
     * @param description Optional description of what happened
     * @param uncaughtError Optional error details from UncaughtErrorEvent
     * @return String path to the created debug package zip file
     */
    public static function collectCrashDebugInfo(
        username:String, 
        email:String, 
        description:String, 
        uncaughtError:String = null
    ):String {
        Logger.info('DebugCollector: Collecting crash debug information');
        
        var timestamp = DateTools.format(Date.now(), "%Y%m%d_%H%M%S");
        var debugPackageName = 'SHI-Crash-Debug-${timestamp}.zip';
        var debugDir = Path.join([System.applicationStorageDirectory, "debug"]);
        var debugPackagePath = Path.join([debugDir, debugPackageName]);
        
        try {
            // Create debug directory if needed
            if (!FileSystem.exists(debugDir)) {
                FileSystem.createDirectory(debugDir);
            }
            
            // Create zip entries
            var entries = new List<Entry>();
            
            // Add crash report info
            var crashInfo = _generateCrashReport(username, email, description, uncaughtError);
            _addStringToZip(entries, "crash-report.txt", crashInfo);
            
            // Add system information
            var systemInfo = _generateSystemInfo();
            _addStringToZip(entries, "system-info.txt", systemInfo);
            
            // Add application logs
            _addLogsToZip(entries, "logs/");
            
            // Add configuration files
            _addConfigFilesToZip(entries);
            
            // Create the zip file
            _writeZipFile(entries, debugPackagePath);
            
            Logger.info('DebugCollector: Created crash debug package at: ${debugPackagePath}');
            return debugPackagePath;
            
        } catch (e:Dynamic) {
            Logger.error('DebugCollector: Error creating crash debug package: ${e}');
            return null;
        }
    }
    
    /**
     * Collect debug information for a server provisioning failure
     * @param server The server that failed
     * @param username User's name for the report
     * @param email User's email for the report
     * @param description Optional description of what happened
     * @return String path to the created debug package zip file
     */
    public static function collectServerDebugInfo(
        server:Server,
        username:String, 
        email:String, 
        description:String
    ):String {
        Logger.info('DebugCollector: Collecting server debug information for server ${server.id}');
        
        var timestamp = DateTools.format(Date.now(), "%Y%m%d_%H%M%S");
        var debugPackageName = 'SHI-Server-Debug-${server.id}-${timestamp}.zip';
        var debugDir = Path.join([System.applicationStorageDirectory, "debug"]);
        var debugPackagePath = Path.join([debugDir, debugPackageName]);
        
        try {
            // Create debug directory if needed
            if (!FileSystem.exists(debugDir)) {
                FileSystem.createDirectory(debugDir);
            }
            
            // Create zip entries
            var entries = new List<Entry>();
            
            // Add server error report
            var serverInfo = _generateServerReport(server, username, email, description);
            _addStringToZip(entries, "server-report.txt", serverInfo);
            
            // Add system information
            var systemInfo = _generateSystemInfo();
            _addStringToZip(entries, "system-info.txt", systemInfo);
            
            // Add application logs
            _addLogsToZip(entries, "logs/");
            
            // Add server-specific files
            _addServerFilesToZip(entries, server, "server-files/");
            
            // Add configuration files
            _addConfigFilesToZip(entries);
            
            // Create the zip file
            _writeZipFile(entries, debugPackagePath);
            
            Logger.info('DebugCollector: Created server debug package at: ${debugPackagePath}');
            return debugPackagePath;
            
        } catch (e:Dynamic) {
            Logger.error('DebugCollector: Error creating server debug package: ${e}');
            return null;
        }
    }
    
    /**
     * Generate crash report information
     */
    private static function _generateCrashReport(
        username:String, 
        email:String, 
        description:String, 
        uncaughtError:String
    ):String {
        var report = new StringBuf();
        
        report.add("=== SUPER HUMAN INSTALLER CRASH REPORT ===\n");
        report.add('Generated: ${Date.now()}\n\n');
        
        report.add("=== CONTACT INFORMATION ===\n");
        report.add('Name: ${username}\n');
        report.add('Email: ${email}\n\n');
        
        if (description != null && description.length > 0) {
            report.add("=== USER DESCRIPTION ===\n");
            report.add('${description}\n\n');
        }
        
        if (uncaughtError != null && uncaughtError.length > 0) {
            report.add("=== ERROR DETAILS ===\n");
            report.add('${uncaughtError}\n\n');
        }
        
        report.add("=== APPLICATION INFO ===\n");
        var app = SuperHumanInstaller.getInstance();
        report.add('Application: ${app.title}\n');
        report.add('Version: ${app.title}\n');
        
        return report.toString();
    }
    
    /**
     * Generate server-specific report information
     */
    private static function _generateServerReport(
        server:Server,
        username:String, 
        email:String, 
        description:String
    ):String {
        var report = new StringBuf();
        
        report.add("=== SUPER HUMAN INSTALLER SERVER DEBUG REPORT ===\n");
        report.add('Generated: ${Date.now()}\n\n');
        
        report.add("=== CONTACT INFORMATION ===\n");
        report.add('Name: ${username}\n');
        report.add('Email: ${email}\n\n');
        
        if (description != null && description.length > 0) {
            report.add("=== USER DESCRIPTION ===\n");
            report.add('${description}\n\n');
        }
        
        report.add("=== SERVER INFORMATION ===\n");
        report.add('Server ID: ${server.id}\n');
        report.add('FQDN: ${server.fqdn}\n');
        report.add('Hostname: ${server.hostname.value}\n');
        report.add('Organization: ${server.organization.value}\n');
        report.add('Status: ${server.status.value}\n');
        report.add('Provisioner Type: ${server.provisioner.type}\n');
        report.add('Provisioner Version: ${server.provisioner.version}\n');
        report.add('Provisioned: ${server.provisioned}\n');
        report.add('VM Exists: ${server.vmExistsInVirtualBox()}\n');
        report.add('Has Execution Errors: ${server.hasExecutionErrors}\n');
        
        // Add role information
        report.add('\n=== ENABLED ROLES ===\n');
        for (role in server.roles.value) {
            if (role.enabled) {
                report.add('- ${role.value}\n');
                if (role.files.installer != null) {
                    report.add('  Installer: ${role.files.installer}\n');
                }
            }
        }
        
        // Add network configuration
        report.add('\n=== NETWORK CONFIGURATION ===\n');
        report.add('DHCP4: ${server.dhcp4.value}\n');
        report.add('Network Address: ${server.networkAddress.value}\n');
        report.add('Network Bridge: ${server.networkBridge.value}\n');
        report.add('Network Gateway: ${server.networkGateway.value}\n');
        report.add('Network Netmask: ${server.networkNetmask.value}\n');
        report.add('Name Server 1: ${server.nameServer1.value}\n');
        report.add('Name Server 2: ${server.nameServer2.value}\n');
        report.add('Disable Bridge Adapter: ${server.disableBridgeAdapter.value}\n');
        
        return report.toString();
    }
    
    /**
     * Generate system information
     */
    private static function _generateSystemInfo():String {
        var info = new StringBuf();
        
        info.add("=== SYSTEM INFORMATION ===\n");
        info.add('OS: ${Capabilities.os}\n');
        info.add('Platform: ${Capabilities.playerType}\n');
        info.add('Language: ${Capabilities.language}\n');
        info.add('CPU Architecture: ${Capabilities.cpuArchitecture}\n');
        
        // Application storage directory
        info.add('App Storage: ${System.applicationStorageDirectory}\n');
        info.add('User Directory: ${System.userDirectory}\n');
        
        // Memory info if available
        try {
            info.add('Total Memory: Unable to determine\n');
        } catch (e:Dynamic) {
            info.add('Total Memory: Unable to determine\n');
        }
        
        // Vagrant/VirtualBox info
        try {
            var vagrant = prominic.sys.applications.hashicorp.Vagrant.getInstance();
            info.add('Vagrant Installed: ${vagrant.exists}\n');
            if (vagrant.exists) {
                info.add('Vagrant Version: ${vagrant.version}\n');
                info.add('Vagrant Path: ${vagrant.path}\n');
            }
            
            var vbox = prominic.sys.applications.oracle.VirtualBox.getInstance();
            info.add('VirtualBox Installed: ${vbox.exists}\n');
            if (vbox.exists) {
                info.add('VirtualBox Version: ${vbox.version}\n');
                info.add('VirtualBox Path: ${vbox.path}\n');
            }
            
            var git = prominic.sys.applications.git.Git.getInstance();
            info.add('Git Installed: ${git.exists}\n');
            if (git.exists) {
                info.add('Git Version: ${git.version}\n');
                info.add('Git Path: ${git.path}\n');
            }
        } catch (e:Dynamic) {
            info.add('Error getting app info: ${e}\n');
        }
        
        return info.toString();
    }
    
    /**
     * Add application logs to the zip package
     */
    private static function _addLogsToZip(entries:List<Entry>, basePath:String):Void {
        try {
            var logsDir = Path.join([System.applicationStorageDirectory, "logs"]);
            
            if (!FileSystem.exists(logsDir) || !FileSystem.isDirectory(logsDir)) {
                Logger.warning('DebugCollector: Logs directory not found at: ${logsDir}');
                return;
            }
            
            var logFiles = FileSystem.readDirectory(logsDir);
            for (logFile in logFiles) {
                var logPath = Path.join([logsDir, logFile]);
                
                // Skip if not a file
                if (!FileSystem.exists(logPath) || FileSystem.isDirectory(logPath)) {
                    continue;
                }
                
                try {
                    var logContent = File.getContent(logPath);
                    var entryPath = basePath + logFile;
                    _addStringToZip(entries, entryPath, logContent);
                    Logger.info('DebugCollector: Added log file: ${logFile}');
                } catch (e:Dynamic) {
                    Logger.warning('DebugCollector: Could not read log file ${logFile}: ${e}');
                }
            }
        } catch (e:Dynamic) {
            Logger.warning('DebugCollector: Error adding logs to zip: ${e}');
        }
    }
    
    /**
     * Add server-specific files to the zip package
     */
    private static function _addServerFilesToZip(entries:List<Entry>, server:Server, basePath:String):Void {
        try {
            var serverDir = server.serverDir;
            
            if (!FileSystem.exists(serverDir) || !FileSystem.isDirectory(serverDir)) {
                Logger.warning('DebugCollector: Server directory not found at: ${serverDir}');
                return;
            }
            
            // Add key server files
            var filesToCollect = [
                "server.shi",           // Server configuration
                "Hosts.yml",           // Generated Hosts file
                "Vagrantfile",         // Vagrant configuration
                ".vagrant/provisioned-adapters.yml", // Provisioning results
                ".vagrant/done.txt",   // Legacy provisioning results
                "results.yml"          // Newer provisioning results
            ];
            
            for (fileName in filesToCollect) {
                var filePath = Path.join([serverDir, fileName]);
                
                if (FileSystem.exists(filePath) && !FileSystem.isDirectory(filePath)) {
                    try {
                        var fileContent = File.getContent(filePath);
                        var entryPath = basePath + StringTools.replace(fileName, "/", "_"); // Flatten paths for simplicity
                        _addStringToZip(entries, entryPath, fileContent);
                        Logger.info('DebugCollector: Added server file: ${fileName}');
                    } catch (e:Dynamic) {
                        Logger.warning('DebugCollector: Could not read server file ${fileName}: ${e}');
                    }
                }
            }
            
            // Add console output if available
            if (server.console != null) {
                try {
                    var console = cast(server.console, superhuman.components.Console);
                    if (console != null && Reflect.hasField(console, "_textList")) {
                        var textList = Reflect.field(console, "_textList");
                        if (textList != null && Reflect.hasField(textList, "getText")) {
                            var consoleText = Reflect.callMethod(textList, Reflect.field(textList, "getText"), []);
                            if (consoleText != null && consoleText != "") {
                                _addStringToZip(entries, basePath + "console-output.txt", consoleText);
                                Logger.info('DebugCollector: Added console output');
                            }
                        }
                    }
                } catch (e:Dynamic) {
                    Logger.warning('DebugCollector: Could not extract console output: ${e}');
                }
            }
            
        } catch (e:Dynamic) {
            Logger.warning('DebugCollector: Error adding server files to zip: ${e}');
        }
    }
    
    /**
     * Add configuration files to the zip package
     */
    private static function _addConfigFilesToZip(entries:List<Entry>):Void {
        try {
            var configFiles = [
                ".shi-config"  // Main application config
            ];
            
            for (configFile in configFiles) {
                var configPath = Path.join([System.applicationStorageDirectory, configFile]);
                
                if (FileSystem.exists(configPath) && !FileSystem.isDirectory(configPath)) {
                    try {
                        var configContent = File.getContent(configPath);
                        _addStringToZip(entries, "config/" + configFile, configContent);
                        Logger.info('DebugCollector: Added config file: ${configFile}');
                    } catch (e:Dynamic) {
                        Logger.warning('DebugCollector: Could not read config file ${configFile}: ${e}');
                    }
                }
            }
        } catch (e:Dynamic) {
            Logger.warning('DebugCollector: Error adding config files to zip: ${e}');
        }
    }
    
    /**
     * Add a string as a file entry to the zip
     */
    private static function _addStringToZip(entries:List<Entry>, fileName:String, content:String):Void {
        try {
            var data = Bytes.ofString(content);
            var entry:Entry = {
                fileName: fileName,
                fileSize: data.length,
                fileTime: Date.now(),
                compressed: false,
                dataSize: data.length,
                data: data,
                crc32: haxe.crypto.Crc32.make(data)
            };
            entries.add(entry);
        } catch (e:Dynamic) {
            Logger.warning('DebugCollector: Could not add string to zip for ${fileName}: ${e}');
        }
    }
    
    /**
     * Write the zip file to disk
     */
    private static function _writeZipFile(entries:List<Entry>, outputPath:String):Void {
        var output = new BytesOutput();
        var writer = new Writer(output);
        writer.write(entries);
        
        var zipBytes = output.getBytes();
        File.saveBytes(outputPath, zipBytes);
        
        Logger.info('DebugCollector: Wrote zip file with ${entries.length} entries to: ${outputPath}');
    }
    
    /**
     * Get the debug packages directory path
     * @return String The path to the debug packages directory
     */
    public static function getDebugPackagesDirectory():String {
        return Path.join([System.applicationStorageDirectory, "debug"]);
    }
    
    /**
     * Clean up old debug package files (optional manual cleanup)
     * This should only be called by user action, not automatically
     */
    public static function cleanupDebugPackage(packagePath:String):Void {
        try {
            if (FileSystem.exists(packagePath)) {
                FileSystem.deleteFile(packagePath);
                Logger.info('DebugCollector: Manually cleaned up debug package: ${packagePath}');
            }
        } catch (e:Dynamic) {
            Logger.warning('DebugCollector: Could not clean up debug package ${packagePath}: ${e}');
        }
    }
}
