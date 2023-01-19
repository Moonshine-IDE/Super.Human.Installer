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

package genesis.application.components;

import feathers.controls.Label;
import feathers.controls.LayoutGroup;
import motion.Actuate;

@:styleContext
class Toast extends LayoutGroup {

    public static function create( message:String, showCloseButton:Bool = true, duration:Float = 1 ):Toast {
        
        var toast:Toast = new Toast( message, showCloseButton, duration );
        return toast;

    }

    private var _duration:Float;
    private var _toastLabel:Label;

    private function new( message:String, showCloseButton:Bool = true, duration:Float = 1 ) {
        
        super();

        this.alpha = 0;
        this._duration = duration;

        _toastLabel = new Label();
        _toastLabel.text = message;
        this.addChild( _toastLabel );

    }

    public function show( parent:LayoutGroup ) {
        
        parent.addChild( this );
        Actuate.tween( this, .5, { alpha:1 } ).onComplete( _hideToast );

    }

    private function _hideToast() {
        
        Actuate.stop( this );
        Actuate.tween( this, 1, { alpha:0 } ).delay( _duration ).onComplete( _removeToast );

    }

    private function _removeToast() {
        
        this.parent.removeChild( this );
        this.removeChildren();

        _toastLabel = null;

    }

}