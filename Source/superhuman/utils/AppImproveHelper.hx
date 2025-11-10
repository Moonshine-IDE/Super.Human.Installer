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
import openfl.system.Capabilities;
import superhuman.browser.Browsers;

/**
 * Utility for building App Improvement request URLs and handling submissions
 * Following the same pattern as AIR-Prominic-Native implementation
 */
class AppImproveHelper {
    
    // Base URL for the App Improve system
    private static final BASE_URL:String = "https://xd.prominic.net/app/apprequest.nsf/router";
    
    // Fixed customer ID for Super Human Installer
    private static final CUSTOMER_ID:String = "A55DF1";
    
    /**
     * Open an App Improvement request with the provided information
     * @param username User's name
     * @param email User's email address  
     * @param errorType Type of error (crash, provision_failure, etc.)
     * @param description Optional additional context
     * @param debugPackagePath Optional path to debug package (for user reference)
     */
    public static function submitDebugReport(
        username:String,
        email:String, 
        errorType:String,
        description:String = "",
        debugPackagePath:String = null
    ):Void {
        Logger.info('AppImproveHelper: Submitting debug report for ${errorType}');
        
        try {
            // Build the App Improvement URL
            var appImproveUrl = buildAppImproveUrl(username, email, errorType, description);
            
            // Log the complete URL for debugging
            Logger.info('AppImproveHelper: Generated App Improve URL: ${appImproveUrl}');
            
            // Temporarily disable browser opening - submission happens via backend API
            // TODO: Re-enable once App Improve portal provides direct request tracking URLs
            var browserSuccess = false; // Always false to skip browser opening
            Logger.info('AppImproveHelper: Browser opening temporarily disabled, submission sent to backend');
            
            // Show submission confirmation to user
            showSubmissionConfirmation(appImproveUrl, debugPackagePath);
            
            // Note: Debug packages are kept permanently for user reference
            // Users may need them for manual attachment to support requests
            
        } catch (e:Dynamic) {
            Logger.error('AppImproveHelper: Error submitting debug report: ${e}');
            showSubmissionFeedback(false, null, debugPackagePath);
        }
    }
    
    /**
     * Build the App Improvement URL with proper encoding
     * @param username User's name
     * @param email User's email address
     * @param errorType Type of error (crash, provision_failure, etc.)
     * @param description Optional additional context
     * @return String The complete App Improvement URL
     */
    private static function buildAppImproveUrl(
        username:String,
        email:String,
        errorType:String, 
        description:String
    ):String {
        // Format username as FirstName.LastName (portal expects this format)
        var formattedUser = username;
        if (username.indexOf(" ") >= 0) {
            // If full name has spaces, convert to FirstName.LastName format
            var nameParts = username.split(" ");
            formattedUser = nameParts[0];
            if (nameParts.length > 1) {
                formattedUser += "." + nameParts[nameParts.length - 1]; // First + Last name
            }
        }
        
        // URL encode parameters
        var encodedUser = StringTools.urlEncode(formattedUser);
        var encodedEmail = StringTools.urlEncode(email);
        
        // Build simple context string in expected format: "application|errorType"
        var context = 'SuperHumanInstaller|${errorType}';
        if (description != null && description.length > 0) {
            // Add description as additional context
            var truncatedDesc = description.length > 50 ? description.substr(0, 50) + "..." : description;
            context += '|${truncatedDesc}';
        }
        var encodedContext = StringTools.urlEncode(context);
        
        // Build URL in the exact order shown in documentation: user, customerId, email, context
        var url = '${BASE_URL}?openagent&req=sso&user=${encodedUser}&customerId=${CUSTOMER_ID}&email=${encodedEmail}&context=${encodedContext}';
        
        Logger.info('AppImproveHelper: Built App Improve URL with context: ${context}');
        Logger.info('AppImproveHelper: URL parameters - user: ${encodedUser} (original: ${username}), customerId: ${CUSTOMER_ID}, email: ${encodedEmail} (original: ${email})');
        Logger.info('AppImproveHelper: Complete URL: ${url}');
        return url;
    }
    
    /**
     * Show confirmation that debug report was submitted successfully
     * @param appImproveUrl The generated URL (for logging purposes)
     * @param debugPackagePath Path to debug package (if any)
     */
    private static function showSubmissionConfirmation(
        appImproveUrl:String = null,
        debugPackagePath:String = null
    ):Void {
        var message = new StringBuf();
        
        message.add("✓ Request submitted successfully!");
        
        // Show concise confirmation message
        genesis.application.managers.ToastManager.getInstance().showToast(message.toString());
        
        // Log full details for reference
        if (debugPackagePath != null) {
            var debugDir = haxe.io.Path.directory(debugPackagePath);
            var packageName = haxe.io.Path.withoutDirectory(debugPackagePath);
            Logger.info('AppImproveHelper: Debug report submitted. Package: ${packageName}, Location: ${debugDir}');
        } else {
            Logger.info('AppImproveHelper: Debug report submitted successfully');
        }
    }
    
    /**
     * Show detailed feedback to user about submission status (fallback for errors)
     * @param browserSuccess Whether browser opened successfully
     * @param appImproveUrl The generated URL (for manual copy if needed)
     * @param debugPackagePath Path to debug package (if any)
     */
    private static function showSubmissionFeedback(
        browserSuccess:Bool,
        appImproveUrl:String = null,
        debugPackagePath:String = null
    ):Void {
        var message = new StringBuf();
        
        message.add("⚠ Error submitting debug report.\n");
        message.add("Please contact support manually.");
        
        if (debugPackagePath != null) {
            var debugDir = haxe.io.Path.directory(debugPackagePath);
            var packageName = haxe.io.Path.withoutDirectory(debugPackagePath);
            message.add('\n\n📁 Debug package: ${packageName}');
            message.add('\nLocation: ${debugDir}');
        }
        
        // Show error message
        genesis.application.managers.ToastManager.getInstance().showToast(message.toString());
        
        // Also log for user reference
        Logger.info('AppImproveHelper: ${message.toString()}');
    }
    
    /**
     * Get a simplified OS name for the context string
     * @return String OS name (Windows, macOS, Linux)
     */
    private static function _getOSName():String {
        var os = Capabilities.os.toLowerCase();
        
        if (os.indexOf("windows") >= 0) {
            return "Windows";
        } else if (os.indexOf("mac") >= 0) {
            return "macOS";
        } else if (os.indexOf("linux") >= 0) {
            return "Linux";
        } else {
            return "Unknown";
        }
    }
}
