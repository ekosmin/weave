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
	import flash.display.BitmapData;
	
	import weave.api.core.ILinkableHashMap;
	import weave.api.data.IAttributeColumn;
	import weave.api.data.IQualifiedKey;
	import weave.api.primitives.IBounds2D;
	import weave.api.registerLinkableChild;
	import weave.api.reportError;
	import weave.api.ui.IPlotTask;
	import weave.api.ui.IPlotter;
	import weave.api.ui.ITextPlotter;
	import weave.core.LinkableFunction;
	import weave.core.LinkableHashMap;

	/**
	 * @author adufilie
	 */
	public class CustomGlyphPlotter extends AbstractGlyphPlotter implements ITextPlotter
	{
		WeaveAPI.ClassRegistry.registerImplementation(IPlotter, CustomGlyphPlotter, "ActionScript glyphs");
		
		public function CustomGlyphPlotter()
		{
			setColumnKeySources([dataX, dataY]);
			vars.childListCallbacks.addImmediateCallback(this, handleVarList);
		}
		private function handleVarList():void
		{
			// When a new column is created, register the stats to trigger callbacks and affect busy status.
			// This will be cleaned up automatically when the column is disposed.
			var newColumn:IAttributeColumn = vars.childListCallbacks.lastObjectAdded as IAttributeColumn;
			if (newColumn)
				registerLinkableChild(vars, WeaveAPI.StatisticsCache.getColumnStatistics(newColumn));
		}
		
		/**
		 * This can hold any objects that should be stored in the session state.
		 */
		public const vars:ILinkableHashMap = newSpatialProperty(LinkableHashMap);
		public const locals:Object = {};
		
		public const function_drawPlot:LinkableFunction = registerLinkableChild(this, new LinkableFunction(script_drawPlot, false, true, ['keys','dataBounds','screenBounds','destination']));
		public static const script_drawPlot:String = <![CDATA[
			// Parameter types: Array, IBounds2D, IBounds2D, BitmapData
			function(keys, dataBounds, screenBounds, destination)
			{
				import 'weave.data.AttributeColumns.DynamicColumn';
				import 'weave.utils.GraphicsBuffer';
			
				var getStats = WeaveAPI.StatisticsCache.getColumnStatistics;
				var colorColumn = vars.requestObject('color', DynamicColumn, false);
				var sizeColumn = vars.requestObject('size', DynamicColumn, false);
				var sizeStats = getStats(sizeColumn);
				var buffer = locals.buffer || (locals.buffer = new GraphicsBuffer());
				var key;
			
				colorColumn.globalName = 'defaultColorColumn';
				buffer.destination(destination)
					.lineStyle(1, 0x000000, 0.5); // weight, color, alpha
			
				for each (key in keys)
				{
					getCoordsFromRecordKey(key, tempPoint); // uses dataX,dataY
					// project x,y data coordinates to screen coordinates
					dataBounds.projectPointTo(tempPoint, screenBounds);
			
					if (isNaN(tempPoint.x) || isNaN(tempPoint.y))
						continue;
					
					var x = tempPoint.x, y = tempPoint.y;
					var size = 20 * sizeStats.getNorm(key);
					var color = colorColumn.getValueFromKey(key, Number);
					
					// draw graphics
					if (isFinite(color))
						buffer.beginFill(color, 1.0); // color, alpha
					if (isNaN(size))
					{
						size = 10;
						buffer.drawRect(x - size/2, y - size/2, size, size);
					}
					else
					{
						buffer.drawCircle(tempPoint.x, tempPoint.y, size);
					}
					buffer.endFill();
				}
				buffer.flush();
			}
		]]>;
		override public function drawPlotAsyncIteration(task:IPlotTask):Number
		{
			try
			{
				// BIG HACK to work properly as a symbolPlotter in GeometryPlotter
				if (task.iteration <= task.recordKeys.length)
					return 0;
				
				function_drawPlot.call(this, task.recordKeys, task.dataBounds, task.screenBounds, task.buffer);
			}
			catch (e:*)
			{
				reportError(e);
			}
			return 1;
		}
		
		public const function_drawBackground:LinkableFunction = registerLinkableChild(this, new LinkableFunction(script_drawBackground, false, true, ['dataBounds', 'screenBounds', 'destination']));
		public static const script_drawBackground:String = <![CDATA[
			// Parameter types: IBounds2D, IBounds2D, BitmapData
			function(dataBounds, screenBounds, destination)
			{
				/*
				import 'weave.utils.GraphicsBuffer';
			
				var graphicBuffer = new GraphicsBuffer(destination);
			
				// draw background graphics here
			
				graphicsBuffer.flush();
				*/
			}
		]]>;
		override public function drawBackground(dataBounds:IBounds2D, screenBounds:IBounds2D, destination:BitmapData):void
		{
			try
			{
				function_drawBackground.apply(this, arguments);
			}
			catch (e:*)
			{
				reportError(e);
			}
		}
		
		public const function_getDataBoundsFromRecordKey:LinkableFunction = registerSpatialProperty(new LinkableFunction(script_getDataBoundsFromRecordKey, false, true, ['key', 'output']));
		public static const script_getDataBoundsFromRecordKey:String = <![CDATA[
			// Parameter types: IQualifiedKey, Array
			function(key, output)
			{
				getCoordsFromRecordKey(key, tempPoint); // uses dataX,dataY
				
				var bounds = initBoundsArray(output);
				bounds.includePoint(tempPoint);
				if (isNaN(tempPoint.x))
					bounds.setXRange(-Infinity, Infinity);
				if (isNaN(tempPoint.y))
					bounds.setYRange(-Infinity, Infinity);
			}
		]]>;
		override public function getDataBoundsFromRecordKey(key:IQualifiedKey, output:Array):void
		{
			try
			{
				function_getDataBoundsFromRecordKey.apply(this, arguments);
			}
			catch (e:*)
			{
				reportError(e);
			}
		}
		
		public const function_getBackgroundDataBounds:LinkableFunction = registerSpatialProperty(new LinkableFunction(script_getBackgroundDataBounds, false, true, ['output']));
		public static const script_getBackgroundDataBounds:String = <![CDATA[
			// Parameter type: IBounds2D
			function (output)
			{
				if (zoomToSubset.value)
				{
					output.reset();
				}
				else
				{
					var getStats = WeaveAPI.StatisticsCache.getColumnStatistics;
					var statsX = getStats(dataX);
					var statsY = getStats(dataY);
					
					output.setBounds(
						statsX.getMin(),
						statsY.getMin(),
						statsX.getMax(),
						statsY.getMax()
					);
				}
			}
		]]>;
		override public function getBackgroundDataBounds(output:IBounds2D):void
		{
			try
			{
				function_getBackgroundDataBounds.apply(this, arguments);
			}
			catch (e:*)
			{
				reportError(e);
			}
		}
	}
}
