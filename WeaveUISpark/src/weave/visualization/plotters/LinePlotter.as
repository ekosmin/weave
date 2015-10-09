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
	
	import weave.api.core.DynamicState;
	import weave.api.data.IQualifiedKey;
	import weave.api.newLinkableChild;
	import weave.api.primitives.IBounds2D;
	import weave.api.registerLinkableChild;
	import weave.api.reportError;
	import weave.api.setSessionState;
	import weave.data.AttributeColumns.AlwaysDefinedColumn;
	import weave.data.AttributeColumns.DynamicColumn;
	import weave.visualization.plotters.styles.SolidLineStyle;

	/**
	 * This plotter plots lines using x1,y1,x2,y2 values.
	 * There is a set of data coordinates and a set of screen offset coordinates.
	 * 
	 * @author adufilie
	 */
	public class LinePlotter extends AbstractPlotter
	{
		public function LinePlotter()
		{
			setColumnKeySources([x1Data, y1Data, x2Data, y2Data]);
		}

		// spatial properties
		/**
		 * This is the beginning X data value associated with the line.
		 */
		public const x1Data:DynamicColumn = newSpatialProperty(DynamicColumn);
		/**
		 * This is the beginning Y data value associated with the line.
		 */
		public const y1Data:DynamicColumn = newSpatialProperty(DynamicColumn);
		/**
		 * This is the ending X data value associated with the line.
		 */
		public const x2Data:DynamicColumn = newSpatialProperty(DynamicColumn);
		/**
		 * This is the ending Y data value associated with the line.
		 */
		public const y2Data:DynamicColumn = newSpatialProperty(DynamicColumn);

		// visual properties
		/**
		 * This is an offset in screen coordinates when projecting the line onto the screen.
		 */
		public const x1ScreenOffset:AlwaysDefinedColumn = registerLinkableChild(this, new AlwaysDefinedColumn(0));
		/**
		 * This is an offset in screen coordinates when projecting the line onto the screen.
		 */
		public const y1ScreenOffset:AlwaysDefinedColumn = registerLinkableChild(this, new AlwaysDefinedColumn(0));
		/**
		 * This is an offset in screen coordinates when projecting the line onto the screen.
		 */
		public const x2ScreenOffset:AlwaysDefinedColumn = registerLinkableChild(this, new AlwaysDefinedColumn(0));
		/**
		 * This is an offset in screen coordinates when projecting the line onto the screen.
		 */
		public const y2ScreenOffset:AlwaysDefinedColumn = registerLinkableChild(this, new AlwaysDefinedColumn(0));
		/**
		 * This is the line style used to draw the line.
		 */
		public const line:SolidLineStyle = newLinkableChild(this, SolidLineStyle);

		/**
		 * This function returns a Bounds2D object set to the data bounds associated with the given record key.
		 * @param key The key of a data record.
		 * @param outputDataBounds A Bounds2D object to store the result in.
		 */
		override public function getDataBoundsFromRecordKey(recordKey:IQualifiedKey, output:Array):void
		{
			initBoundsArray(output, 2);
			(output[0] as IBounds2D).includeCoords(
					x1Data.getValueFromKey(recordKey, Number),
					y1Data.getValueFromKey(recordKey, Number)
				);
			(output[1] as IBounds2D).includeCoords(
					x2Data.getValueFromKey(recordKey, Number),
					y2Data.getValueFromKey(recordKey, Number)
				);
		}

		/**
		 * This function may be defined by a class that extends AbstractPlotter to use the basic template code in AbstractPlotter.drawPlot().
		 */
		override protected function addRecordGraphicsToTempShape(recordKey:IQualifiedKey, dataBounds:IBounds2D, screenBounds:IBounds2D, tempShape:Shape):void
		{
			var graphics:Graphics = tempShape.graphics;

			// project data coordinates to screen coordinates and draw graphics onto tempShape
			line.beginLineStyle(recordKey, graphics);				
			
			// project data coordinates to screen coordinates and draw graphics
			tempPoint.x = x1Data.getValueFromKey(recordKey, Number);
			tempPoint.y = y1Data.getValueFromKey(recordKey, Number);
			dataBounds.projectPointTo(tempPoint, screenBounds);
			tempPoint.x += x1ScreenOffset.getValueFromKey(recordKey, Number);
			tempPoint.y += y1ScreenOffset.getValueFromKey(recordKey, Number);
			
			graphics.moveTo(tempPoint.x, tempPoint.y);
			
			tempPoint.x = x2Data.getValueFromKey(recordKey, Number);
			tempPoint.y = y2Data.getValueFromKey(recordKey, Number);
			dataBounds.projectPointTo(tempPoint, screenBounds);
			tempPoint.x += x2ScreenOffset.getValueFromKey(recordKey, Number);
			tempPoint.y += y2ScreenOffset.getValueFromKey(recordKey, Number);
			
			graphics.lineTo(tempPoint.x, tempPoint.y);
		}
		
		private static const tempPoint:Point = new Point(); // reusable object
		
		[Deprecated(replacement="line")] public function set lineStyle(value:Object):void
		{
			try
			{
				setSessionState(line, value[0][DynamicState.SESSION_STATE]);
			}
			catch (e:Error)
			{
				reportError(e);
			}
		}
	}
}
