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

package superhuman.components;

import feathers.controls.Alert;
import feathers.controls.Button;
import feathers.controls.Label;
import feathers.controls.LayoutGroup;
import feathers.controls.ScrollContainer;
import superhuman.theme.SuperHumanInstallerTheme;
import feathers.core.PopUpManager;
import feathers.events.TriggerEvent;
import feathers.layout.HorizontalAlign;
import feathers.layout.HorizontalLayout;
import feathers.layout.HorizontalLayoutData;
import feathers.layout.VerticalAlign;
import feathers.layout.VerticalLayout;
import feathers.layout.VerticalLayoutData;
import genesis.application.components.HLine;
import genesis.application.theme.GenesisApplicationTheme;
import openfl.display.DisplayObjectContainer;
import openfl.display.Sprite;
import openfl.Lib;

/**
 * A utility class for showing dialogs with vertically-arranged options.
 * This is particularly useful for showing lists of files or other options
 * that may have longer text and need more horizontal space.
 */
class VerticalOptionsAlert {
    
    /**
     * Static method to create and show an alert with vertical options.
     * @param message The message to display in the alert.
     * @param title The title of the alert.
     * @param options Array of option strings to display as buttons.
     * @param callback Function to call when an option is selected.
     * @param parentSprite The parent sprite to center the alert on.
     * @param closeOnPopUpOverlay Whether to close when clicking outside the alert.
     * @param cancelButtonIndex Optional index for the cancel button (will use different styling).
     * @return The created Alert instance.
     */
    public static function show(
        message:String, 
        title:String, 
        options:Array<String>, 
        callback:(state:{index:Int}) -> Void,
        ?parentSprite:Sprite,
        closeOnPopUpOverlay:Bool = false,
        ?cancelButtonIndex:Int
    ):Alert {
        // Define consistent width and padding for all components
        final dialogWidth:Float = GenesisApplicationTheme.GRID * 85; // Increased by another 15% for more content space
        final paddingPercent:Float = 0.015; // 1.5% padding on each side
        
        // Create an alert with no buttons (we'll add them manually in the content)
        var alert = Alert.show("", title, [], null);
        
        // Set the alert to be wider to prevent text clipping
        alert.width = dialogWidth;
        
        // Create simple content container with vertical layout
        var content = new LayoutGroup();
        content.width = dialogWidth;
        content.layoutData = new VerticalLayoutData(100);
        
        var verticalLayout = new VerticalLayout();
        verticalLayout.gap = GenesisApplicationTheme.GRID * 2;
        verticalLayout.paddingTop = GenesisApplicationTheme.GRID * 2;
        verticalLayout.horizontalAlign = HorizontalAlign.CENTER; // Center alignment for cancel button
        content.layout = verticalLayout;
        
        // Add message if provided
        if (message != null && message.length > 0) {
            var messageLabel = new Label(message);
            messageLabel.wordWrap = true;
            messageLabel.layoutData = new VerticalLayoutData(100);
            content.addChild(messageLabel);
            
            // Add separator
            var separator = new HLine();
            separator.alpha = 0.3;
            separator.width = dialogWidth * 0.97; // 97% of dialog width
            separator.layoutData = new VerticalLayoutData(97);
            content.addChild(separator);
        }
        
        // Create a scroll container for the option buttons
        var scrollContainer = new ScrollContainer();
        scrollContainer.variant = SuperHumanInstallerTheme.SCROLL_CONTAINER_DARK;
        scrollContainer.backgroundSkin = null; // Remove the background
        scrollContainer.width = dialogWidth * 0.97; // 97% of dialog width
        scrollContainer.layoutData = new VerticalLayoutData(97); // 97% width of container
        scrollContainer.maxHeight = GenesisApplicationTheme.GRID * 30; // Set a reasonable max height
        
        // Set up vertical layout for the scroll container
        var scrollLayout = new VerticalLayout();
        scrollLayout.horizontalAlign = HorizontalAlign.JUSTIFY; // Justify content to fill width
        scrollLayout.paddingLeft = scrollLayout.paddingRight = dialogWidth * paddingPercent; // 1.5% padding on each side
        scrollLayout.gap = GenesisApplicationTheme.GRID;
        scrollContainer.layout = scrollLayout;
        
        // Add file selection buttons (all except cancel) to scroll container
        for (i in 0...options.length) {
            // Skip the cancel button for now
            if (cancelButtonIndex != null && i == cancelButtonIndex) continue;
            
            // Create the button with 100% width to fill scroll container
            var button = new Button(options[i]);
            button.layoutData = new VerticalLayoutData(100); // 100% width of scroll container
            
            // Store the option index for use in the event handler
            var optionIndex = i;
            
            // Add click handler
            button.addEventListener(TriggerEvent.TRIGGER, function(e:TriggerEvent) {
                // Close the alert using PopUpManager
                try {
                    PopUpManager.removePopUp(alert);
                } catch (e:Dynamic) {
                    // Silently ignore any errors closing the alert
                }
                
                // Call the callback with the selected index
                if (callback != null) {
                    callback({index: optionIndex});
                }
            });
            
            // Add button to the scroll container
            scrollContainer.addChild(button);
        }
        
        // Add the scroll container to the main content
        content.addChild(scrollContainer);
        
        // Only add separator line and cancel button if needed
        if (cancelButtonIndex != null) {
            // Add separator line for visual separation
            var separator = new HLine();
            separator.alpha = 0.3;
            separator.width = dialogWidth * 0.97; // 97% of dialog width
            separator.layoutData = new VerticalLayoutData(97);
            content.addChild(separator);
            
            // Add Cancel button with natural width
            var cancelButton = new Button(options[cancelButtonIndex]);
            cancelButton.width = GenesisApplicationTheme.GRID * 20; // Fixed width for natural appearance
            
            // Add click handler for cancel button
            cancelButton.addEventListener(TriggerEvent.TRIGGER, function(e:TriggerEvent) {
                // Close the alert using PopUpManager
                try {
                    PopUpManager.removePopUp(alert);
                } catch (e:Dynamic) {
                    // Silently ignore any errors closing the alert
                }
                
                // Call the callback with the cancel index
                if (callback != null) {
                    callback({index: cancelButtonIndex});
                }
            });
            
            // Add button directly to content with natural width
            content.addChild(cancelButton);
        }
        
        // Add custom content to the alert
        alert.addChild(content);
        
        return alert;
    }
}
