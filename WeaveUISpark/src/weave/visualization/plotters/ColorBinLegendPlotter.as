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
	import flash.display.Graphics;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.utils.Dictionary;
	
	import weave.Weave;
	import weave.api.data.IColumnStatistics;
	import weave.api.data.IQualifiedKey;
	import weave.api.newLinkableChild;
	import weave.api.primitives.IBounds2D;
	import weave.api.registerLinkableChild;
	import weave.api.ui.IPlotTask;
	import weave.api.ui.ISelectableAttributes;
	import weave.api.ui.ITextPlotter;
	import weave.compiler.StandardLib;
	import weave.core.LinkableBoolean;
	import weave.core.LinkableFunction;
	import weave.core.LinkableNumber;
	import weave.core.LinkableString;
	import weave.core.LinkableWatcher;
	import weave.data.AttributeColumns.BinnedColumn;
	import weave.data.AttributeColumns.ColorColumn;
	import weave.data.AttributeColumns.DynamicColumn;
	import weave.primitives.Bounds2D;
	import weave.utils.BitmapText;
	import weave.utils.ColumnUtils;
	import weave.utils.LegendUtils;
	import weave.utils.LinkableTextFormat;
	import weave.visualization.plotters.styles.SolidLineStyle;
	
	/**
	 * This plotter displays a legend for a ColorColumn.  If the ColorColumn contains a BinnedColumn, a list of bins
	 * with their corresponding colors will be displayed.  If not a continuous color scale will be displayed.  By
	 * default this plotter links to the static color column, but it can be linked to another by changing or removing
	 * the dynamicColorColumn.staticName value.
	 * 
	 * @author adufilie
	 */
	public class ColorBinLegendPlotter extends AbstractPlotter implements ITextPlotter, ISelectableAttributes
	{
		public function ColorBinLegendPlotter()
		{
			dynamicColorColumn.globalName = Weave.DEFAULT_COLOR_COLUMN;
			
			setSingleKeySource(dynamicColorColumn);
			registerLinkableChild(this, LinkableTextFormat.defaultTextFormat); // redraw when text format changes
		}
		
		public function getSelectableAttributeNames():Array
		{
			return ["Color data"];
		}
		public function getSelectableAttributes():Array
		{
			return [dynamicColorColumn];
		}
		
		/**
		 * This plotter is specifically implemented for visualizing a ColorColumn.
		 * This DynamicColumn only allows internal columns of type ColorColumn.
		 */
		public const dynamicColorColumn:DynamicColumn = registerSpatialProperty(new DynamicColumn(ColorColumn), createHashMaps);
		
		/**
		 * This accessor function provides convenient access to the internal ColorColumn, which may be null.
		 * The public session state is defined by dynamicColorColumn.
		 */
		public function getInternalColorColumn():ColorColumn
		{
			return dynamicColorColumn.getInternalColumn() as ColorColumn;
		}
		
		/**
		 * This is the type of shape to be drawn for each legend item.
		 */		
		public const shapeType:LinkableString = registerLinkableChild(this, new LinkableString(SHAPE_TYPE_CIRCLE, verifyShapeType));
		public static const SHAPE_TYPE_CIRCLE:String = 'circle';
		public static const SHAPE_TYPE_SQUARE:String = 'square';
		public static const SHAPE_TYPE_LINE:String = 'line';
		public static const ENUM_SHAPE_TYPE:Array = [SHAPE_TYPE_CIRCLE, SHAPE_TYPE_SQUARE, SHAPE_TYPE_LINE];
		private function verifyShapeType(value:String):Boolean { return ENUM_SHAPE_TYPE.indexOf(value) >= 0; }
		
		/**
		 * This is the radius of the circle, in screen coordinates.
		 */
		public const shapeSize:LinkableNumber = registerLinkableChild(this, new LinkableNumber(25));
		/**
		 * This is the line style used to draw the outline of the shape.
		 */
		public const lineStyle:SolidLineStyle = newLinkableChild(this, SolidLineStyle);
		
		/**
		 * This is the maximum number of items to draw in a single row.
		 * @default 1 
		 */		
		public const maxColumns:LinkableNumber = registerSpatialProperty(new LinkableNumber(1), createHashMaps);
		
		/**
		 * This is an option to reverse the item order.
		 */
		public const reverseOrder:LinkableBoolean = registerSpatialProperty(new LinkableBoolean(false), createHashMaps);
		
		/**
		 * This is the compiled function to apply to the item labels.
		 */		
		public const itemLabelFunction:LinkableFunction = registerSpatialProperty(new LinkableFunction('string', true, false, ['number', 'string']), createHashMaps);
		
		// TODO This should go somewhere else...
		/**
		 * This is the compiled function to apply to the title of the tool.
		 */		
		public const legendTitleFunction:LinkableFunction = registerLinkableChild(this, new LinkableFunction('column.getMetadata("title")', true, false, ['string', 'column']));
		
		private const statsWatcher:LinkableWatcher = newLinkableChild(this, LinkableWatcher);
		
		private var _binToBounds:Array = [];
		private var _binToString:Array = [];
		public var numBins:int = 0;
		private function createHashMaps():void
		{
			_binToString = [];
			_binToBounds = [];
			
			var keys:Array = filteredKeySet.keys;
			var internalColorColumn:ColorColumn = getInternalColorColumn();
			if (!internalColorColumn)
				return;
			
			var binnedColumn:BinnedColumn = internalColorColumn.getInternalColumn() as BinnedColumn;
			if (binnedColumn == null)
			{
				numBins = 0;
				return;
			}
			
			numBins = binnedColumn.numberOfBins;
			var maxCols:int = maxColumns.value;
			if (maxCols <= 0)
				maxCols = 1;
			if (maxCols > numBins)
				maxCols = numBins;
			var blankBins:int = numBins % maxCols;
			var fakeNumBins:int = (blankBins > 0) ? maxCols - blankBins : 0; // invisible bins which should be put in the lower right 
			var maxNumBins:int = numBins + fakeNumBins;
			for (var iBin:int = 0; iBin < numBins; ++iBin)
			{
				// get the adjusted position and transpose inside the row
				var adjustedIBin:int = (reverseOrder.value) ? (fakeNumBins + iBin) : (maxNumBins - 1 - iBin);
				var row:int = adjustedIBin / maxCols;
				var col:int = adjustedIBin % maxCols;
				var b:IBounds2D = new Bounds2D();
				
				getBackgroundDataBounds(tempBounds);
				LegendUtils.getBoundsFromItemID(tempBounds, adjustedIBin, b, maxNumBins, maxCols, true);
				
				_binToBounds[iBin] = b;
				var binString:String = binnedColumn.deriveStringFromNumber(iBin);
				try
				{
					_binToString[iBin] = itemLabelFunction.apply(null, [iBin, binString]);
				}
				catch (e:Error)
				{
					_binToString[iBin] = binString;
				}
			}
		}
		
		private var _drawBackground:Boolean = false; // this is used to check if we should draw the bins with no records.
		override public function drawBackground(dataBounds:IBounds2D, screenBounds:IBounds2D, destination:BitmapData):void
		{
			// draw the bins that have no records in them in the background
			_drawBackground = true;
			drawAll(filteredKeySet.keys, dataBounds, screenBounds, destination);
			_drawBackground = false;
		}

		override public function drawPlotAsyncIteration(task:IPlotTask):Number
		{
			drawAll(task.recordKeys, task.dataBounds, task.screenBounds, task.buffer);
			return 1;
		}
		private function drawAll(recordKeys:Array, dataBounds:IBounds2D, screenBounds:IBounds2D, destination:BitmapData):void
		{
			var internalColorColumn:ColorColumn = getInternalColorColumn();
			if (internalColorColumn == null)
				return; // draw nothing
			var binnedColumn:BinnedColumn = internalColorColumn.getInternalColumn() as BinnedColumn;
			if (binnedColumn && binnedColumn.numberOfBins)
				drawBinnedPlot(recordKeys, dataBounds, screenBounds, destination);
			else
				drawContinuousPlot(recordKeys, dataBounds, screenBounds, destination);
		}
			
		protected function drawContinuousPlot(recordKeys:Array, dataBounds:IBounds2D, screenBounds:IBounds2D, destination:BitmapData):void
		{
			if (!_drawBackground)
				return;
			
			var _shapeSize:Number = shapeSize.value;
			var colorColumn:ColorColumn = getInternalColorColumn();
			var dataColumn:DynamicColumn = colorColumn.internalDynamicColumn;
			var stats:IColumnStatistics = WeaveAPI.StatisticsCache.getColumnStatistics(dataColumn);
			statsWatcher.target = stats;
			
			tempBounds.copyFrom(screenBounds);
			tempBounds.makeSizePositive();
			tempBounds.setXMax(_shapeSize + labelGap);
			
			tempShape.graphics.clear();
			colorColumn.ramp.draw(tempShape, 0, reverseOrder.value ? -1 : 1, tempBounds);
			lineStyle.beginLineStyle(null, tempShape.graphics);
			tempShape.graphics.drawRect(tempBounds.getXNumericMin(), tempBounds.getYNumericMin(), tempBounds.getXCoverage() - 1, tempBounds.getYCoverage() - 1);
			
			var minLabel:String = ColumnUtils.deriveStringFromNumber(dataColumn, colorColumn.getDataMin());
			LegendUtils.renderLegendItemText(destination, minLabel, screenBounds, _shapeSize + labelGap, null, reverseOrder.value ? BitmapText.VERTICAL_ALIGN_BOTTOM : BitmapText.VERTICAL_ALIGN_TOP);
			
			if (colorColumn.rampCenterAtZero.value)
			{
				var midLabel:String = ColumnUtils.deriveStringFromNumber(dataColumn, 0);
				LegendUtils.renderLegendItemText(destination, midLabel, screenBounds, _shapeSize + labelGap, null, BitmapText.VERTICAL_ALIGN_MIDDLE);
			}
			
			var maxLabel:String = ColumnUtils.deriveStringFromNumber(dataColumn, colorColumn.getDataMax());
			LegendUtils.renderLegendItemText(destination, maxLabel, screenBounds, _shapeSize + labelGap, null, reverseOrder.value ? BitmapText.VERTICAL_ALIGN_TOP : BitmapText.VERTICAL_ALIGN_BOTTOM);
			
			destination.draw(tempShape);
		}
		
		protected function drawBinnedPlot(recordKeys:Array, dataBounds:IBounds2D, screenBounds:IBounds2D, destination:BitmapData):void
		{
			var colorColumn:ColorColumn = getInternalColorColumn();
			var binnedColumn:BinnedColumn = colorColumn.getInternalColumn() as BinnedColumn;
			
			var g:Graphics = tempShape.graphics;
			g.clear();
			lineStyle.beginLineStyle(null, g);
			
			// convert record keys to bin keys
			// save a mapping of each bin key found to a value of true
			var binIndexMap:Dictionary = new Dictionary();
			for (var i:int = 0; i < recordKeys.length; i++)
				binIndexMap[ binnedColumn.getValueFromKey(recordKeys[i], Number) ] = 1;
			
			var _shapeSize:Number = shapeSize.value;
			if (shapeType.value != SHAPE_TYPE_LINE)
				_shapeSize = Math.max(1, Math.min(_shapeSize, screenBounds.getYCoverage() / numBins));
			var xShapeOffset:Number = _shapeSize / 2; 
			var stats:IColumnStatistics = WeaveAPI.StatisticsCache.getColumnStatistics(colorColumn.internalDynamicColumn);
			statsWatcher.target = stats;
			var binCount:int = binnedColumn.numberOfBins;
			for (var iBin:int = 0; iBin < binCount; ++iBin)
			{
				// we only render empty bins when _drawBackground is true
				if (binIndexMap[iBin] ? _drawBackground : !_drawBackground)
					continue;
				
				tempBounds.copyFrom(_binToBounds[iBin]);
				dataBounds.projectCoordsTo(tempBounds, screenBounds);
				
				// draw almost invisible rectangle for probe filter
				tempBounds.getRectangle(tempRectangle);
				destination.fillRect(tempRectangle, 0x02808080);
				
				// draw the text
				LegendUtils.renderLegendItemText(destination, _binToString[iBin], tempBounds, _shapeSize + labelGap);
				
				// draw circle
				var iColorIndex:int = reverseOrder.value ? (binCount - 1 - iBin) : iBin;
				var color:Number = colorColumn.getColorFromDataValue(iBin);
				var xMin:Number = tempBounds.getXNumericMin(); 
				var yMin:Number = tempBounds.getYNumericMin();
				var xMax:Number = tempBounds.getXNumericMax(); 
				var yMax:Number = tempBounds.getYNumericMax();
				if (isFinite(color))
					g.beginFill(color, 1.0);
				switch (shapeType.value)
				{
					case SHAPE_TYPE_CIRCLE:
						g.drawCircle(xMin + xShapeOffset, (yMin + yMax) / 2, _shapeSize / 2);
						break;
					case SHAPE_TYPE_SQUARE:
						g.drawRect(
							xMin + xShapeOffset - _shapeSize / 2,
							(yMin + yMax - _shapeSize) / 2,
							_shapeSize,
							_shapeSize
						);
						break;
					case SHAPE_TYPE_LINE:
						if (!isFinite(color))
							break;
						g.endFill();
						g.lineStyle(lineShapeThickness, color, 1);
						g.moveTo(xMin + xShapeOffset - _shapeSize / 2, (yMin + yMax) / 2);
						g.lineTo(xMin + xShapeOffset + _shapeSize / 2, (yMin + yMax) / 2);
						break;
				}
				g.endFill();
			}
			destination.draw(tempShape);
		}
		
		public var labelGap:Number = 5;
		public var lineShapeThickness:Number = 4;
		
		// reusable temporary objects
		private const tempPoint:Point = new Point();
		private const tempBounds:IBounds2D = new Bounds2D();
		private const tempRectangle:Rectangle = new Rectangle();
		
		override public function getDataBoundsFromRecordKey(recordKey:IQualifiedKey, output:Array):void
		{
			initBoundsArray(output);
			var internalColorColumn:ColorColumn = getInternalColorColumn();
			if (!internalColorColumn)
				return;
			
			var binnedColumn:BinnedColumn = internalColorColumn.getInternalColumn() as BinnedColumn;
			if (binnedColumn)
			{
				var index:Number = binnedColumn.getValueFromKey(recordKey, Number);
				var b:IBounds2D = _binToBounds[index];
				if (b)
					(output[0] as IBounds2D).copyFrom(b);
			}
		}
		
		override public function getBackgroundDataBounds(output:IBounds2D):void
		{
			return output.setBounds(0, 1, 1, 0);
		}
		
		// backwards compatibility
		[Deprecated(replacement="reverseOrder")] public function set ascendingOrder(value:Boolean):void { reverseOrder.value = !value; }
	}
}
