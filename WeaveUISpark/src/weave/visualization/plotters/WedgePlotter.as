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
	import weave.api.reportError;
	import weave.api.setSessionState;
	import weave.data.AttributeColumns.DynamicColumn;
	import weave.primitives.Bounds2D;
	import weave.utils.DrawUtils;
	import weave.visualization.plotters.styles.SolidFillStyle;
	import weave.visualization.plotters.styles.SolidLineStyle;
	
	/**
	 * WedgePlotter
	 * 
	 * @author skota
	 * @author adufilie
	 */
	public class WedgePlotter extends AbstractPlotter
	{
		public function WedgePlotter()
		{
			setColumnKeySources([beginRadians]);
		}
		
		public const beginRadians:DynamicColumn = newSpatialProperty(DynamicColumn);
		public const spanRadians:DynamicColumn = newSpatialProperty(DynamicColumn);
		
		public const line:SolidLineStyle = newLinkableChild(this, SolidLineStyle);
		public const fill:SolidFillStyle = newLinkableChild(this, SolidFillStyle);		

		/**
		 * This function may be defined by a class that extends AbstractPlotter to use the basic template code in AbstractPlotter.drawPlot().
		 */
		override protected function addRecordGraphicsToTempShape(recordKey:IQualifiedKey, dataBounds:IBounds2D, screenBounds:IBounds2D, tempShape:Shape):void
		{
			// project data coordinates to screen coordinates and draw graphics
			var _beginRadians:Number = beginRadians.getValueFromKey(recordKey, Number);
			var _spanRadians:Number = spanRadians.getValueFromKey(recordKey, Number);

			var graphics:Graphics = tempShape.graphics;
			// begin line & fill
			line.beginLineStyle(recordKey, graphics);				
			fill.beginFillStyle(recordKey, graphics);
			// move to center point
			drawProjectedWedge(graphics, dataBounds, screenBounds, _beginRadians, _spanRadians);
			// end fill
			graphics.endFill();
		}
		private static const tempBounds:IBounds2D = new Bounds2D();
		private static const tempPoint:Point = new Point(); // reusable object, output of projectPoints()
		
		/**
		 * The data bounds for a glyph has width and height equal to zero.
		 * This function returns a Bounds2D object set to the data bounds associated with the given record key.
		 * @param key The key of a data record.
		 * @param output An Array of IBounds2D objects to store the result in.
		 */
		override public function getDataBoundsFromRecordKey(recordKey:IQualifiedKey, output:Array):void
		{
			var _beginRadians:Number = beginRadians.getValueFromKey(recordKey, Number);
			var _pieWidthRadians:Number = spanRadians.getValueFromKey(recordKey, Number);
			getWedgeBounds(initBoundsArray(output), _beginRadians, _pieWidthRadians);
		}
		
		// gets data bounds for a wedge
		public static function getWedgeBounds(outputDataBounds:IBounds2D, beginRadians:Number, spanRadians:Number, xDataCenter:Number = 0, yDataCenter:Number = 0, dataRadius:Number = 1):void
		{
			///////////////////
			//TODO: change this to include begin & end arc points, then any arc points at intervals of pi/2 radians between begin & end arc points
			///////////////////
			
			outputDataBounds.reset();
			
			outputDataBounds.includeCoords(xDataCenter, yDataCenter);
			
			// This is the number of points on the arc used to generate the bounding box of a wedge.
			var numAnchors:Number = 25;
			var differentialRadians:Number = spanRadians/numAnchors;
			for(var counter:Number = 0; counter <= numAnchors; ++counter)
			{
				var x:Number = xDataCenter + dataRadius * Math.cos(beginRadians + counter * differentialRadians);
				var y:Number = yDataCenter + dataRadius * Math.sin(beginRadians + counter * differentialRadians);
				
				outputDataBounds.includeCoords(x, y);
			}
		}

		// projects data coordinates to screen coordinates and draws wedge
		public static function drawProjectedWedge(destination:Graphics, dataBounds:IBounds2D, screenBounds:IBounds2D, beginRadians:Number, spanRadians:Number, xDataCenter:Number = 0, yDataCenter:Number = 0, dataOuterRadius:Number = 1, dataInnerRadius:Number = 0):void
		{
			tempPoint.x = xDataCenter;
			tempPoint.y = yDataCenter;
			dataBounds.projectPointTo(tempPoint, screenBounds);
			var xScreenCenter:Number = tempPoint.x;
			var yScreenCenter:Number = tempPoint.y;
			// convert x,y distance from data coordinates to screen coordinates to get screen radius
			var xScreenRadius:Number = dataOuterRadius * screenBounds.getWidth() / dataBounds.getWidth();
			var yScreenRadius:Number = dataOuterRadius * screenBounds.getHeight() / dataBounds.getHeight();
			
			// move to beginning of outer arc, draw outer arc and output start coordinates to tempPoint
			DrawUtils.arcTo(destination, false, xScreenCenter, yScreenCenter, beginRadians, beginRadians + spanRadians, xScreenRadius, yScreenRadius, tempPoint);
			if (dataInnerRadius == 0)
			{
				// continue line to center
				destination.lineTo(xScreenCenter, yScreenCenter);
			}
			else
			{
				// continue line to inner arc, draw inner arc
				xScreenRadius = dataInnerRadius * screenBounds.getWidth() / dataBounds.getWidth();
				yScreenRadius = dataInnerRadius * screenBounds.getHeight() / dataBounds.getHeight();
				DrawUtils.arcTo(destination, true, xScreenCenter, yScreenCenter, beginRadians + spanRadians, beginRadians, xScreenRadius, yScreenRadius);
			}
			// continue line back to start of outer arc
			destination.lineTo(tempPoint.x, tempPoint.y);
		}
		
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
