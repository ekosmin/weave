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

package weave.visualization.plotters
{
	import flash.display.Graphics;
	import flash.display.Shape;
	import flash.geom.Point;
	
	import weave.Weave;
	import weave.api.data.IQualifiedKey;
	import weave.api.primitives.IBounds2D;
	import weave.api.registerLinkableChild;
	import weave.api.ui.IPlotter;
	import weave.core.LinkableBoolean;
	import weave.core.LinkableString;
	import weave.data.AttributeColumns.AlwaysDefinedColumn;
	import weave.visualization.plotters.styles.SolidFillStyle;
	import weave.visualization.plotters.styles.SolidLineStyle;

	/**
	 * Plots squares or circles.
	 * 
	 * @author adufilie
	 */
	public class SimpleGlyphPlotter extends AbstractGlyphPlotter
	{
		WeaveAPI.ClassRegistry.registerImplementation(IPlotter, SimpleGlyphPlotter, "Simple glyphs");
		
		public function SimpleGlyphPlotter()
		{
			fillStyle.color.internalDynamicColumn.globalName = Weave.DEFAULT_COLOR_COLUMN;
			setColumnKeySources([screenSize, dataX, dataY], [-1, 1, -1]);
		}
		
		private static const LEFT:String = 'left', CENTER:String = 'center', RIGHT:String = 'right';
		private static const TOP:String = 'top', MIDDLE:String = 'middle', BOTTOM:String = 'bottom';
		private static const HORIZONTAL_MODES:Array = [LEFT,CENTER,RIGHT];
		private static const VERTICAL_MODES:Array = [TOP,MIDDLE,BOTTOM];
		private static function verifyHorizontal(value:String):Boolean { return HORIZONTAL_MODES.indexOf(value) >= 0; }
		private static function verifyVertical(value:String):Boolean { return VERTICAL_MODES.indexOf(value) >= 0; }
		
		/**
		 * This is the line style used to draw the outline of the rectangle.
		 */
		public const lineStyle:SolidLineStyle = registerLinkableChild(this, new SolidLineStyle());
		/**
		 * This is the fill style used to fill the rectangle.
		 */
		public const fillStyle:SolidFillStyle = registerLinkableChild(this, new SolidFillStyle());
		/**
		 * This determines the screen size of the glyphs.
		 */
		public const screenSize:AlwaysDefinedColumn = registerSpatialProperty(new AlwaysDefinedColumn());
		/**
		 * If this is true, ellipses will be drawn instead of rectangles.
		 */
		public const drawEllipse:LinkableBoolean = registerLinkableChild(this, new LinkableBoolean(false));
		/**
		 * This determines how the glyphs are aligned horizontally to the data coordinates.
		 */		
		public const horizontalPosition:LinkableString = registerLinkableChild(this, new LinkableString(CENTER, verifyHorizontal));
		/**
		 * This determines how the glyphs are aligned vertically to the data coordinates.
		 */		
		public const verticalPosition:LinkableString = registerLinkableChild(this, new LinkableString(MIDDLE, verifyVertical));
		
		/**
		 * This function may be defined by a class that extends AbstractPlotter to use the basic template code in AbstractPlotter.drawPlot().
		 */
		override protected function addRecordGraphicsToTempShape(recordKey:IQualifiedKey, dataBounds:IBounds2D, screenBounds:IBounds2D, tempShape:Shape):void
		{
			getCoordsFromRecordKey(recordKey, tempPoint);
			var size:Number = screenSize.getValueFromKey(recordKey, Number);
			
			if (isNaN(tempPoint.x) || isNaN(tempPoint.y) || isNaN(size))
				return;
			
			// project x,y data coordinates to screen coordinates
			dataBounds.projectPointTo(tempPoint, screenBounds);
			
			// add screen offsets
			tempPoint.x += size * (HORIZONTAL_MODES.indexOf(horizontalPosition.value) / 2 - 1);
			tempPoint.y += size * (VERTICAL_MODES.indexOf(verticalPosition.value) / 2 - 1);
			
			// draw graphics
			var graphics:Graphics = tempShape.graphics;
			lineStyle.beginLineStyle(recordKey, graphics);
			fillStyle.beginFillStyle(recordKey, graphics);
			
			if (drawEllipse.value)
				graphics.drawEllipse(tempPoint.x, tempPoint.y, size, size);
			else
				graphics.drawRect(tempPoint.x, tempPoint.y, size, size);
			
			graphics.endFill();
		}
		
		private static const tempPoint:Point = new Point(); // reusable object
	}
}
