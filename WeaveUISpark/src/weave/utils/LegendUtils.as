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
	import flash.geom.Rectangle;
	
	import weave.api.primitives.IBounds2D;

	/**
	 * A collection of static methods for drawing and positioning legend items.
	 * 
	 * @author kmonico
	 */	
	public class LegendUtils
	{
		/**
		 * This function will fill in outputScreenBounds with the bounds of the item, relative to
		 * the legend placement. 
		 * @param fullScreenBounds The full bounds of the screen.
		 * @param index The index of the item relative to totalItemCount.
		 * @param outputScreenBounds The output bounds in screen coordinates.
		 * @param totalItemCount The total number of items in the legend.
		 * @param maxColumns The maximum number of columns. When a column is filled, the next item is placed
		 * at the beginning of the next row.
		 * @param transposeInRow If <code>true</code>, then the column of the item will be transposed inside the row.
		 * For example, with maxColumns = 5 (columns 0 .. 4), an item in column 0 would be transposed to column 4. An item in
		 * column 3 would be transposed to column 1, etc.
		 */		
		public static function getBoundsFromItemID(fullScreenBounds:IBounds2D, index:int, outputScreenBounds:IBounds2D, totalItemCount:int, maxColumns:int = 1, transposeInRow:Boolean = false):void
		{
			if (maxColumns <= 0)
				maxColumns = 1;
			if (maxColumns > totalItemCount)
				maxColumns = totalItemCount;
			var maxRows:int = Math.ceil(totalItemCount / maxColumns);

			var xSpacing:Number = fullScreenBounds.getXCoverage() / maxColumns;
			var ySpacing:Number = fullScreenBounds.getYCoverage() / maxRows;
			var desiredColumn:int = index % maxColumns;
			var desiredRow:int = index / maxColumns;
			if (transposeInRow)
				desiredColumn = (maxColumns - 1) - desiredColumn;
			
			var xMinDesired:Number = fullScreenBounds.getXNumericMin() + xSpacing * desiredColumn;
			var yMinDesired:Number = fullScreenBounds.getYNumericMin() + ySpacing * desiredRow;
			var xMaxDesired:Number = xMinDesired + xSpacing;
			var yMaxDesired:Number = yMinDesired + ySpacing;
			outputScreenBounds.setBounds(xMinDesired, yMinDesired, xMaxDesired, yMaxDesired);			
		}
		
		/**
		 * This function will render the text on the destination bitmap.
		 * @param destination The bitmap on which to render the text.
		 * @param text The text to draw on the bitmap.
		 * @param itemScreenBounds The screen bounds of the item.
		 * @param xOffset The label X offset value.
		 * @param clipRectangle A rectangle used for clipping, if desired. This is typically the bounds of the 
		 * screen during a drawPlot or drawBackground call.
		 */
		public static function renderLegendItemText(destination:BitmapData, text:String, itemScreenBounds:IBounds2D, xOffset:int, clipRectangle:Rectangle = null, verticalAlign:String = 'middle'):void
		{
			LinkableTextFormat.defaultTextFormat.copyTo(bitmapText.textFormat);
			
			bitmapText.verticalAlign = BitmapText.VERTICAL_ALIGN_MIDDLE;
			
			bitmapText.text = text;
			bitmapText.verticalAlign = verticalAlign;
			bitmapText.x = itemScreenBounds.getXNumericMin() + xOffset;
			bitmapText.maxWidth = itemScreenBounds.getXCoverage() - xOffset;
			switch (verticalAlign)
			{
				default:
				case BitmapText.VERTICAL_ALIGN_MIDDLE:
					bitmapText.y = itemScreenBounds.getYCenter();
					bitmapText.maxHeight = itemScreenBounds.getYCoverage();
				break;
				case BitmapText.VERTICAL_ALIGN_BOTTOM:
					bitmapText.y = itemScreenBounds.getYNumericMax();
					bitmapText.maxHeight = itemScreenBounds.getYCoverage();
				break;
				case BitmapText.VERTICAL_ALIGN_TOP:
					bitmapText.y = itemScreenBounds.getYNumericMin();
					bitmapText.maxHeight = itemScreenBounds.getYCoverage();
				break;
			}
			bitmapText.draw(destination, null, null, null, clipRectangle); 
		}
		
		private static const bitmapText:BitmapText = new BitmapText();
	}
}