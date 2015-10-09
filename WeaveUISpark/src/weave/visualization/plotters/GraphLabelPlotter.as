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
	import flash.geom.Point;
	import flash.geom.Rectangle;
	
	import weave.api.data.IAttributeColumn;
	import weave.api.data.IQualifiedKey;
	import weave.api.graphs.IGraphAlgorithm;
	import weave.api.graphs.IGraphNode;
	import weave.api.newLinkableChild;
	import weave.api.primitives.IBounds2D;
	import weave.api.registerLinkableChild;
	import weave.api.ui.IPlotTask;
	import weave.core.LinkableNumber;
	import weave.core.LinkableString;
	import weave.data.AttributeColumns.DynamicColumn;
	import weave.primitives.Bounds2D;
	import weave.utils.BitmapText;
	import weave.utils.LinkableTextFormat;
	import weave.utils.ObjectPool;
	import weave.visualization.plotters.styles.SolidFillStyle;
	import weave.visualization.plotters.styles.SolidLineStyle;

	/**
	 * A plotter for placing and rendering labels on the graph plotter.
	 * This is a separate plotter for probing.
	 * 
	 * @author kmonico
	 */	
	public class GraphLabelPlotter extends AbstractPlotter
	{
		public function GraphLabelPlotter()
		{
			super();
			setSingleKeySource(nodesColumn);
			//nodesColumn.addImmediateCallback(this, setKeySource, [nodesColumn], true);
			registerLinkableChild(this, LinkableTextFormat.defaultTextFormat); // redraw when text format changes
		}

		public function runCallbacks():void
		{
			spatialCallbacks.triggerCallbacks();
		}
		
		override public function drawPlotAsyncIteration(task:IPlotTask):Number
		{
			// TODO Figure out why fillRect alpha isn't working
			// don't let labels overlap nodes (might need a separate KDTree to handle this)
			// dynamically place labels
			
			if (!(task.asyncState is Function))
			{
				// these variables are used to save state between function calls
				var i:int;
				var textWasDrawn:Array = [];
				var reusableBoundsObjects:Array = [];
				var bounds:IBounds2D;
				var nodes:Array = [];
				
				task.asyncState = function():Number
				{
					if (task.iteration < task.recordKeys.length)
					{
						var recordKey:IQualifiedKey = task.recordKeys[task.iteration];
						var node:IGraphNode = (layoutAlgorithm as IGraphAlgorithm).getNodeFromKey(recordKey);
						
						// project data coordinates to screen coordinates and draw graphics onto tempShape
						tempDataPoint.x = node.position.x;
						tempDataPoint.y = node.position.y;
						task.dataBounds.projectPointTo(tempDataPoint, task.screenBounds);
		
						// round to nearest pixel to get clearer text
						bitmapText.x = Math.round(tempDataPoint.x);
						bitmapText.y = Math.round(tempDataPoint.y);
						bitmapText.text = labelColumn.getValueFromKey(recordKey, String) as String;
		
						LinkableTextFormat.defaultTextFormat.copyTo(bitmapText.textFormat);
						bitmapText.verticalAlign = BitmapText.VERTICAL_ALIGN_MIDDLE;
						
						// grab a bounds object to store the screen size of the bitmap text
						bounds = reusableBoundsObjects[i] = ObjectPool.borrowObject(Bounds2D);
						bitmapText.getUnrotatedBounds(bounds);
						bounds.offset(radius.value, 0);
						bitmapText.x = bounds.getXMin();
						//					bitmapText.y = bounds.getYMin();
						
						// brute force check to see if this bounds overlaps with any previous bounds
						var overlaps:Boolean = false;
						var j:int;
						for (j = 0; j < i; j++)
						{
							if (textWasDrawn[j] && bounds.overlaps(reusableBoundsObjects[j] as IBounds2D))
							{
								overlaps = true;
								break;
							}
						}
		
						// The code below is _TOO_ _SLOW_ to be used. With 500 nodes, this function takes 250ms+
//						for (j = 0; j < nodes.length; ++j)
//						{
//							if (bounds.overlaps((nodes[j] as IGraphNode).bounds))
//							{
//								overlaps = true;
//								break;
//							}
//						}
						
						if (overlaps)
						{
							textWasDrawn[task.iteration] = false;
						}
						else
						{
							textWasDrawn[task.iteration] = true;
							
							if (bitmapText.angle == 0)
							{
								// draw almost-invisible rectangle behind text
								bitmapText.getUnrotatedBounds(tempBounds);
								tempBounds.getRectangle(tempRectangle);
								task.buffer.fillRect(tempRectangle, 0x02808080);
							}
							
							bitmapText.draw(task.buffer);
						}
						
						return task.iteration / task.recordKeys.length;
					}
					return 1; // avoids divide-by-zero when there are no record keys
				}; // end task function
			} // end if
			
			return (task.asyncState as Function).apply(this, arguments);
		}
		
		override public function getDataBoundsFromRecordKey(recordKey:IQualifiedKey, output:Array):void
		{
			initBoundsArray(output);
			var bounds:IBounds2D = output[0];
			
			if (!layoutAlgorithm)
				return;
			
			var node:IGraphNode = (layoutAlgorithm as IGraphAlgorithm).getNodeFromKey(recordKey);
			if (node)
				bounds.includePoint(node.position);
		}
		
		override public function getBackgroundDataBounds(output:IBounds2D):void
		{
			if (layoutAlgorithm)
				(layoutAlgorithm as IGraphAlgorithm).getOutputBounds(filteredKeySet.keys, output);
			else
				output.reset();
		}				
		
		private function handleColumnsChange():void
		{
//			(layoutAlgorithm as IGraphAlgorithm).setupData(nodesColumn, edgeSourceColumn, edgeTargetColumn);
		}
		
		// the styles
		public const lineStyle:SolidLineStyle = newLinkableChild(this, SolidLineStyle);
		public const fillStyle:SolidFillStyle = newLinkableChild(this, SolidFillStyle);

//		public const sizeColumn:AlwaysDefinedColumn = registerLinkableChild(this, new AlwaysDefinedColumn());
		public const labelColumn:DynamicColumn = registerSpatialProperty(new DynamicColumn(IAttributeColumn), handleColumnsChange);
		public const nodesColumn:DynamicColumn = registerSpatialProperty(new DynamicColumn(IAttributeColumn), handleColumnsChange);
		public const edgeSourceColumn:DynamicColumn = registerSpatialProperty(new DynamicColumn(IAttributeColumn), handleColumnsChange);
		public const edgeTargetColumn:DynamicColumn = registerSpatialProperty(new DynamicColumn(IAttributeColumn), handleColumnsChange);		
		public const radius:LinkableNumber = registerSpatialProperty(new LinkableNumber(2)); // radius of the circles

		public var layoutAlgorithm:IGraphAlgorithm = null;
		//public const layoutAlgorithm:LinkableDynamicObject = registerSpatialProperty(new LinkableDynamicObject(IGraphAlgorithm), handleColumnsChange);
		public const currentAlgorithm:LinkableString = registerLinkableChild(this, new LinkableString());

		private const tempRectangle:Rectangle = new Rectangle();
		private const tempDataPoint:Point = new Point(); // reusable object
		private const bitmapText:BitmapText = new BitmapText();
		private const tempBounds:IBounds2D = new Bounds2D(); // reusable object
	}
}