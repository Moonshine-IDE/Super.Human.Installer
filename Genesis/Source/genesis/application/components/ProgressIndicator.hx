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

import feathers.core.FeathersControl;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.PixelSnapping;
import openfl.events.Event;
import openfl.geom.Matrix;
import openfl.geom.Point;

/**
 * Rotating ProgressIndicator component. Use this for displaying progress
 * that does not have a minimum and a maximum value.
 */
class ProgressIndicator extends FeathersControl {

    var alphaStep:Float;
    var bmp:Bitmap;
    var bmpd:BitmapData;
    var center:Point;
    var color:Int;
    var currentAngle:Float;
    var currentSegment:Int = 0;
    var odd:Bool = false;
    var pad:Float;
    var rotating:Bool = false;
    var segments:Int = 16;
    var size:Float;
    var sprite:FeathersControl;
    var step:Float;
    var thickness:Float = 15;

    /**
     * Creates a ProgressIndicator component. The shapes are drawn onto Graphics, then rendered
     * into a transparent Bitmap for better quality and performance.
     * @param size The width and height of the component
     * @param segments How many segments (lines) should be drawn
     * @param color The color of the component's segments (lines)
     */
    public function new( size:Float = 100, segments:Int = 16, color:Int = 0 ) {

        super();

        this.width = this.height = size;
        this.size = size / 2;
        this.pad = this.size * .5;
        this.color = color;
        this.center = new Point( this.size / 2, this.size / 2 );
        this.thickness = this.size * .14;
        this.segments = segments;

    }

    override function initialize() {

        super.initialize();

        step = 360 / segments;
        alphaStep = 1 / segments;

        sprite = new FeathersControl();
        sprite.width = sprite.height = this.width;

        for ( i in 0...segments ) {

            currentAngle = i * step;
            sprite.graphics.lineStyle( thickness, color, 1 - i * alphaStep );
            var rad = currentAngle * ( Math.PI / 180 );
            var fromX = pad * Math.sin( rad );
            var fromY = pad * Math.cos( rad );
            var toX = ( size - thickness ) * Math.sin( rad );
            var toY = ( size - thickness ) * Math.cos( rad );
            sprite.graphics.moveTo( fromX, fromY );
            sprite.graphics.lineTo( toX, toY );

        }

        bmpd = new BitmapData( Std.int( size * 2 ), Std.int( size * 2 ), true, 0xFF0000 );
        var mtrx:Matrix = new Matrix();
        mtrx.translate( size, size );
        bmpd.draw( sprite, mtrx );
        bmp = new Bitmap( bmpd, PixelSnapping.AUTO, true );
        sprite.graphics.clear();
        bmp.x = bmp.y = -size;
        sprite.x = sprite.y = size;
        sprite.addChild( bmp );
        this.addChild( sprite );

        this.addEventListener( Event.ENTER_FRAME, enterFrame );

    }

    /**
     * Start rotation
     */
    public function start() {

        rotating = true;

    }

    /**
     * Stop rotation
     */
    public function stop() {

        rotating = false;

    }

    function enterFrame( e:Event ) {

        if ( !rotating ) return;

        odd = !odd;

        if ( odd ) {

            if ( sprite != null ) {

                sprite.rotation += step;
                
            }

        }

    }

}