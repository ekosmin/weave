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
	import weave.api.core.DynamicState;
	import weave.api.data.ColumnMetadata;
	import weave.api.data.DataType;
	import weave.api.data.IAttributeColumn;
	import weave.api.data.IQualifiedKey;
	import weave.api.newLinkableChild;
	import weave.api.primitives.IBounds2D;
	import weave.api.registerLinkableChild;
	import weave.api.reportError;
	import weave.api.setSessionState;
	import weave.api.ui.ISelectableAttributes;
	import weave.api.ui.IPlotter;
	import weave.core.LinkableBoolean;
	import weave.data.AttributeColumns.AlwaysDefinedColumn;
	import weave.primitives.Bounds2D;
	import weave.primitives.GeneralizedGeometry;
	import weave.visualization.plotters.styles.SolidFillStyle;
	import weave.visualization.plotters.styles.SolidLineStyle;

	/**
	 * This plotter plots rectangles using xMin,yMin,xMax,yMax values.
	 * There is a set of data coordinates and a set of screen offset coordinates.
	 * 
	 * @author adufilie
	 */
	public class RectanglePlotter extends AbstractPlotter implements ISelectableAttributes
	{
		WeaveAPI.ClassRegistry.registerImplementation(IPlotter, RectanglePlotter, "Rectangles");
		
		public function RectanglePlotter()
		{
			// initialize default line & fill styles
			fill.color.internalDynamicColumn.globalName = Weave.DEFAULT_COLOR_COLUMN;
			
			setColumnKeySources(
				[xData, yData, widthData, heightData, xMinScreenOffset, yMinScreenOffset, xMaxScreenOffset, yMaxScreenOffset],
				[1, 1, -1, -1]
			);
		}
		
		public function getSelectableAttributeNames():Array
		{
			return ['Fill Color', 'X', 'Y', 'Width', 'Height', 'xMin Screen Offset', 'yMin Screen Offset', 'xMax Screen Offset', 'yMax Screen Offset'];
		}
		
		public function getSelectableAttributes():Array
		{
			return [fill.color, xData, yData, widthData, heightData, xMinScreenOffset, yMinScreenOffset, xMaxScreenOffset, yMaxScreenOffset];
		}
		
		// spatial properties
		/**
		 * This is the minimum X data value associated with the rectangle.
		 */
		public const xData:AlwaysDefinedColumn = registerSpatialProperty(new AlwaysDefinedColumn());
		/**
		 * This is the minimum Y data value associated with the rectangle.
		 */
		public const yData:AlwaysDefinedColumn = registerSpatialProperty(new AlwaysDefinedColumn());
		/**
		 * This is the maximum X data value associated with the rectangle.
		 */
		public const widthData:AlwaysDefinedColumn = registerSpatialProperty(new AlwaysDefinedColumn(0));
		/**
		 * This is the maximum Y data value associated with the rectangle.
		 */
		public const heightData:AlwaysDefinedColumn = registerSpatialProperty(new AlwaysDefinedColumn(0));
		
		/**
		 * If this is true, the rectangle will be centered on xData coordinates.
		 */
		public const centerX:LinkableBoolean = registerSpatialProperty(new LinkableBoolean(false));
		/**
		 * If this is true, the rectangle will be centered on yData coordinates.
		 */
		public const centerY:LinkableBoolean = registerSpatialProperty(new LinkableBoolean(false));

		// visual properties
		/**
		 * This is an offset in screen coordinates when projecting the data rectangle onto the screen.
		 */
		public const xMinScreenOffset:AlwaysDefinedColumn = registerLinkableChild(this, new AlwaysDefinedColumn(0));
		/**
		 * This is an offset in screen coordinates when projecting the data rectangle onto the screen.
		 */
		public const yMinScreenOffset:AlwaysDefinedColumn = registerLinkableChild(this, new AlwaysDefinedColumn(0));
		/**
		 * This is an offset in screen coordinates when projecting the data rectangle onto the screen.
		 */
		public const xMaxScreenOffset:AlwaysDefinedColumn = registerLinkableChild(this, new AlwaysDefinedColumn(0));
		/**
		 * This is an offset in screen coordinates when projecting the data rectangle onto the screen.
		 */
		public const yMaxScreenOffset:AlwaysDefinedColumn = registerLinkableChild(this, new AlwaysDefinedColumn(0));
		/**
		 * This is the line style used to draw the outline of the rectangle.
		 */
		public const line:SolidLineStyle = newLinkableChild(this, SolidLineStyle);
		/**
		 * This is the fill style used to fill the rectangle.
		 */
		public const fill:SolidFillStyle = newLinkableChild(this, SolidFillStyle);
		/**
		 * If this is true, ellipses will be drawn instead of rectangles.
		 */
		public const drawEllipse:LinkableBoolean = registerLinkableChild(this, new LinkableBoolean(false));

		protected function getCoordFromRecordKey(recordKey:IQualifiedKey, trueXfalseY:Boolean):Number
		{
			var dataCol:IAttributeColumn = trueXfalseY ? xData : yData;
			if (dataCol.getMetadata(ColumnMetadata.DATA_TYPE) == DataType.GEOMETRY)
			{
				var geoms:Array = dataCol.getValueFromKey(recordKey, Array) as Array;
				var geom:GeneralizedGeometry;
				if (geoms && geoms.length)
					geom = geoms[0] as GeneralizedGeometry;
				if (geom)
					return trueXfalseY ? geom.bounds.getXCenter() : geom.bounds.getYCenter();
			}
			return dataCol.getValueFromKey(recordKey, Number);
		}
		
		/**
		 * This function returns a Bounds2D object set to the data bounds associated with the given record key.
		 * @param key The key of a data record.
		 * @param outputDataBounds An Array of IBounds2D objects to store the result in.
		 */
		override public function getDataBoundsFromRecordKey(recordKey:IQualifiedKey, output:Array):void
		{
			getBounds(recordKey, initBoundsArray(output));
		}
		
		private function getBounds(recordKey:IQualifiedKey, output:IBounds2D):void
		{
			var x:Number = getCoordFromRecordKey(recordKey, true);
			var y:Number = getCoordFromRecordKey(recordKey, false);
			var width:Number = widthData.getValueFromKey(recordKey, Number);
			var height:Number = heightData.getValueFromKey(recordKey, Number);
			
			if (centerX.value)
				output.setCenteredXRange(x, width);
			else
				output.setXRange(x, x + width);
			
			if (centerY.value)
				output.setCenteredYRange(y, height);
			else
				output.setYRange(y, y + height);
		}

		/**
		 * This function may be defined by a class that extends AbstractPlotter to use the basic template code in AbstractPlotter.drawPlot().
		 */
		override protected function addRecordGraphicsToTempShape(recordKey:IQualifiedKey, dataBounds:IBounds2D, screenBounds:IBounds2D, tempShape:Shape):void
		{
			var graphics:Graphics = tempShape.graphics;

			// project data coordinates to screen coordinates and draw graphics onto tempShape
			getBounds(recordKey, tempBounds);
			
			// project x,y data coordinates to screen coordinates
			tempBounds.getMinPoint(tempPoint);
			dataBounds.projectPointTo(tempPoint, screenBounds);
			// add screen offsets
			tempPoint.x += xMinScreenOffset.getValueFromKey(recordKey, Number);
			tempPoint.y += yMinScreenOffset.getValueFromKey(recordKey, Number);
			// save x,y screen coordinates
			tempBounds.setMinPoint(tempPoint);
			
			// project x+w,y+h data coordinates to screen coordinates
			tempBounds.getMaxPoint(tempPoint);
			dataBounds.projectPointTo(tempPoint, screenBounds);
			// add screen offsets
			tempPoint.x += xMaxScreenOffset.getValueFromKey(recordKey, Number);
			tempPoint.y += yMaxScreenOffset.getValueFromKey(recordKey, Number);
			// save x+w,y+h screen coordinates
			tempBounds.setMaxPoint(tempPoint);
			
			// draw graphics
			tempBounds.makeSizePositive();
			line.beginLineStyle(recordKey, graphics);
			fill.beginFillStyle(recordKey, graphics);
			if (drawEllipse.value)
				graphics.drawEllipse(tempBounds.getXMin(), tempBounds.getYMin(), tempBounds.getWidth(), tempBounds.getHeight());
			else
				graphics.drawRect(tempBounds.getXMin(), tempBounds.getYMin(), tempBounds.getWidth(), tempBounds.getHeight());
			graphics.endFill();
		}
		
		private static const tempBounds:IBounds2D = new Bounds2D(); // reusable object
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
		[Deprecated(replacement="fill")] public function set fillStyle(value:Object):void
		{
			try
			{
				setSessionState(fill, value[0][DynamicState.SESSION_STATE]);
			}
			catch (e:Error)
			{
				reportError(e);
			}
		}
	}
}
