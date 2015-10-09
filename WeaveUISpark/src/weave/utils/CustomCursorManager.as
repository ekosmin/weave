/* ***** BEGIN LICENSE BLOCK *****
 *
 * This file is part of Weave.
 *
 * The Initial Developer of Weave is the Institute for Visualization
 * and Perception Research at the University of Massachusetts Lowell.
 * Portions created by the Initial Developer are Copyright (C) 2008-2015
 * the Initial Developer. All Rights Reserved.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at http://mozilla.org/MPL/2.0/.
 * 
 * ***** END LICENSE BLOCK ***** */

package weave.utils
{
	import flash.display.BitmapData;
	import flash.geom.Point;
	import flash.system.Capabilities;
	import flash.ui.Mouse;
	import flash.ui.MouseCursor;
	import flash.ui.MouseCursorData;
	
	import mx.core.BitmapAsset;

	/**
	 * Easy interface for using native cursors.
	 * 
	 * @author skolman
	 * @author adufilie
	 */	
	public class CustomCursorManager
	{
		public static var debug:Boolean = false;
		
		private static var _initialized:Boolean = false;
		private static var _customCursorsSupported:Boolean = true;
		public static function get customCursorsSupported():Boolean
		{
			if (!_initialized)
			{
				if (Capabilities.manufacturer == "Adobe Linux" && JavaScript.available)
				{
					_customCursorsSupported = JavaScript.exec(
						'try {',
						'	return this.children.wmode.value != "transparent";',
						'} catch (e) { return true; }'
					);
				}
				_initialized = true;
			}
			return _customCursorsSupported;
		}
		
		/**
		 * This will register an embedded cursor.
		 * To embed a cursor in your own class, follow this example:
		 * <code>
		 *    public static const MY_CURSOR:String = "myCursor";
		 *    [Embed(source="/weave/resources/images/myCursor.png")]
		 *    private static var myCursor:Class;
		 *    CustomCursorManager.registerEmbeddedCursor(MY_CURSOR, myCursor, 0, 0);
		 * </code>
		 * @param cursorName A name for the cursor.
		 * @param bitmapAsset The Class containing the embedded cursor image.
		 * @param xHotSpot The X coordinate of the hot spot.  Set to NaN to use the center X coordinate.
		 * @param yHotSpot The Y coordinate of the hot spot.  Set to NaN to use the center Y coordinate.
		 */		
        public static function registerEmbeddedCursor(name:String, bitmapAssetClass:Class, xHotSpot:Number, yHotSpot:Number):void
		{
			var asset:BitmapAsset = new bitmapAssetClass() as BitmapAsset;
			if (isNaN(xHotSpot))
				xHotSpot = asset.width / 2;
			if (isNaN(yHotSpot))
				yHotSpot = asset.height / 2;
			registerCursor(name, asset.bitmapData, xHotSpot, yHotSpot);
		}
		
		/**
		 * This will register a BitmapData object as a cursor.
		 * @param cursorName A reasonably unique name for the cursor.
		 * @param bitmapData The cursor image.
		 * @param xHotSpot The X coordinate for the hot spot.
		 * @param yHotSpot The Y coordinate for the hot spot.
		 */
        public static function registerCursor(cursorName:String, bitmapData:BitmapData, xHotSpot:int = 0, yHotSpot:int = 0):void
		{
			var cursorData:MouseCursorData = new MouseCursorData();
			cursorData.data = Vector.<BitmapData>([bitmapData]);
			cursorData.hotSpot = new Point(xHotSpot, yHotSpot);
			Mouse.registerCursor(cursorName, cursorData);
		}
		
        private static var idCounter:int = 1; // used to generate unique IDs for cursors
		private static const cursorStack:Array = []; // keeps track of previously shown cursors
		
		/**
		 * This function is to set the cursor to standard cursor types like hand cursor, link cursor, etc.
		 * Look at the static String constants to get all the types of available cursors.
		 * @param name The name of a registered cursor.
		 * @return An id mapped to the cursor that can be passed to removeCursor() later.
		 * */
		public static function showCursor(name:String):int
		{
			if (!name)
				throw new Error("cursor name cannot be null");
			cursorStack.push(new CursorEntry(idCounter, name));
			updateCursor();
			return idCounter++; // increment for next time
		}
		
		/**
		 * Removes a cursor previously shown.
		 * @param id The id of the cursor that was returned by a previous call to showCursor().
		 */
		public static function removeCursor(id:int):void
		{
			for (var i:int; i < cursorStack.length; i++)
			{
				if (CursorEntry(cursorStack[i]).id == id)
				{
					cursorStack.splice(i,1);
					updateCursor();
					return;
				}
			}
		}
		
		/**
		 * This function should always be called after modifying the cursor stack.
		 */		
		private static function updateCursor():void
		{
			if (cursorStack.length > 0)
			{
				var entry:CursorEntry = CursorEntry(cursorStack[cursorStack.length - 1]);
				try
				{
					Mouse.cursor = entry.name;
				}
				catch (e:Error)
				{
					if (debug)
						trace('Unable to set cursor to "' + entry.name + '"');
				}
			}
			else
				Mouse.cursor = MouseCursor.AUTO;
		}
		
		//  FlexGlobals.topLevelApplication.addElement(new('weave.visualization.layers.SimpleInteractiveVisualization'))
		
		///////////
		// hacks //
		///////////
		
		/**
		 * @private
		 * @TODO Stop using this function and remove it.
		 */
		[Deprecated(replacement="removeCursor")] public static function hack_removeCurrentCursor():void
		{
			if (cursorStack.length == 0)
				return;

			cursorStack.pop();
			updateCursor();
		}
		
		/**
		 * @private
		 * @TODO Stop using this function and remove it.
		 */
		[Deprecated(replacement="removeCursor")] public static function hack_removeAllCursors():void
		{
			cursorStack.length = 0;
			updateCursor();
		}
	}
}
import flash.ui.MouseCursor;

import weave.utils.CustomCursorManager;

internal class CursorEntry
{
	public function CursorEntry(id:int, name:String)
	{
		this.id = id;
		if (CustomCursorManager.customCursorsSupported)
			this.name = name;
		else
			this.name = MouseCursor.BUTTON;
	}
	
	public var id:Number;
	public var name:String;
}
