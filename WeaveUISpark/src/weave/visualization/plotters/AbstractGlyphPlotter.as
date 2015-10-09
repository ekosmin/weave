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
	import flash.utils.Dictionary;
	
	import weave.api.data.ColumnMetadata;
	import weave.api.data.DataType;
	import weave.api.data.IAttributeColumn;
	import weave.api.data.IColumnStatistics;
	import weave.api.data.IKeySet;
	import weave.api.data.IProjector;
	import weave.api.data.IQualifiedKey;
	import weave.api.detectLinkableObjectChange;
	import weave.api.linkSessionState;
	import weave.api.newDisposableChild;
	import weave.api.primitives.IBounds2D;
	import weave.api.registerLinkableChild;
	import weave.api.ui.IObjectWithDescription;
	import weave.core.LinkableBoolean;
	import weave.core.LinkableString;
	import weave.data.AttributeColumns.DynamicColumn;
	import weave.data.AttributeColumns.FilteredColumn;
	import weave.data.AttributeColumns.ProxyColumn;
	import weave.data.KeySets.FilteredKeySet;
	import weave.primitives.GeneralizedGeometry;
	import weave.utils.ColumnUtils;
	
	/**
	 * A glyph represents a point of data at an X and Y coordinate.
	 * 
	 * @author adufilie
	 */
	public class AbstractGlyphPlotter extends AbstractPlotter implements IObjectWithDescription
	{
		public function AbstractGlyphPlotter()
		{
			clipDrawing = false;
			
			setColumnKeySources([dataX, dataY]);
			
			// filter x and y columns so background data bounds will be correct
			filteredDataX.filter.requestLocalObject(FilteredKeySet, true);
			filteredDataY.filter.requestLocalObject(FilteredKeySet, true);
			
			registerSpatialProperty(dataX);
			registerSpatialProperty(dataY);
			
			linkSessionState(_filteredKeySet.keyFilter, filteredDataX.filter);
			linkSessionState(_filteredKeySet.keyFilter, filteredDataY.filter);
		}
		
		public function getDescription():String
		{
			var titleX:String = dataX.getMetadata(ColumnMetadata.TITLE);
			if (dataX.getMetadata(ColumnMetadata.DATA_TYPE) == DataType.GEOMETRY)
			{
				if (destinationProjection.value && sourceProjection.value != destinationProjection.value)
					return lang('{0} ({1} -> {2})', titleX, sourceProjection.value || '?', destinationProjection.value);
				else if (sourceProjection.value)
					return lang('{0} ({1})', titleX, sourceProjection.value);
				return titleX;
			}
			var titleY:String = dataY.getMetadata(ColumnMetadata.TITLE);
			return lang('{0} vs. {1}', titleX || ProxyColumn.DATA_UNAVAILABLE, titleY || ProxyColumn.DATA_UNAVAILABLE);
		}
		
		protected const filteredDataX:FilteredColumn = newDisposableChild(this, FilteredColumn);
		protected const filteredDataY:FilteredColumn = newDisposableChild(this, FilteredColumn);
		public const zoomToSubset:LinkableBoolean = registerSpatialProperty(new LinkableBoolean(false));
		
		protected const statsX:IColumnStatistics = registerLinkableChild(this, WeaveAPI.StatisticsCache.getColumnStatistics(filteredDataX));
		protected const statsY:IColumnStatistics = registerLinkableChild(this, WeaveAPI.StatisticsCache.getColumnStatistics(filteredDataY));
		
		public function hack_setSingleKeySource(keySet:IKeySet):void
		{
			setSingleKeySource(keySet);
		}
		
		public function get dataX():DynamicColumn
		{
			return filteredDataX.internalDynamicColumn;
		}
		public function get dataY():DynamicColumn
		{
			return filteredDataY.internalDynamicColumn;
		}
		
		public const sourceProjection:LinkableString = newSpatialProperty(LinkableString);
		public const destinationProjection:LinkableString = newSpatialProperty(LinkableString);
		
		public const tempPoint:Point = new Point();
		private var _projector:IProjector;
		private var _xCoordCache:Dictionary;
		private var _yCoordCache:Dictionary;
		
		/**
		 * This gets called whenever any of the following change: dataX, dataY, sourceProjection, destinationProjection
		 */		
		private function updateProjector():void
		{
			_xCoordCache = new Dictionary(true);
			_yCoordCache = new Dictionary(true);
			
			var sourceSRS:String = sourceProjection.value;
			var destinationSRS:String = destinationProjection.value;
			
			// if sourceSRS is missing and both X and Y projections are the same, use that.
			if (!sourceSRS)
			{
				var projX:String = dataX.getMetadata(ColumnMetadata.PROJECTION);
				var projY:String = dataY.getMetadata(ColumnMetadata.PROJECTION);
				if (projX == projY)
					sourceSRS = projX;
			}
			
			if (sourceSRS && destinationSRS)
				_projector = WeaveAPI.ProjectionManager.getProjector(sourceSRS, destinationSRS);
			else
				_projector = null;
		}
		
		public function getCoordsFromRecordKey(recordKey:IQualifiedKey, output:Point):void
		{
			if (detectLinkableObjectChange(updateProjector, dataX, dataY, sourceProjection, destinationProjection))
				updateProjector();
			
			if (_xCoordCache[recordKey] !== undefined)
			{
				output.x = _xCoordCache[recordKey];
				output.y = _yCoordCache[recordKey];
				return;
			}
			
			for (var i:int = 0; i < 2; i++)
			{
				var result:Number = NaN;
				var dataCol:IAttributeColumn = i == 0 ? dataX : dataY;
				if (dataCol.getMetadata(ColumnMetadata.DATA_TYPE) == DataType.GEOMETRY)
				{
					var geoms:Array = dataCol.getValueFromKey(recordKey, Array) as Array;
					var geom:GeneralizedGeometry;
					if (geoms && geoms.length)
						geom = geoms[0] as GeneralizedGeometry;
					if (geom)
					{
						if (i == 0)
							result = geom.bounds.getXCenter();
						else
							result = geom.bounds.getYCenter();
					}
				}
				else
				{
					result = dataCol.getValueFromKey(recordKey, Number);
				}
				
				if (i == 0)
				{
					output.x = result;
					_xCoordCache[recordKey] = result;
				}
				else
				{
					output.y = result;
					_yCoordCache[recordKey] = result;
				}
			}
			if (_projector)
			{
				_projector.reproject(output);
				_xCoordCache[recordKey] = output.x;
				_yCoordCache[recordKey] = output.y;
			}
		}
		
		/**
		 * The data bounds for a glyph has width and height equal to zero.
		 * This function returns a Bounds2D object set to the data bounds associated with the given record key.
		 * @param key The key of a data record.
		 * @param output An Array of IBounds2D objects to store the result in.
		 */
		override public function getDataBoundsFromRecordKey(recordKey:IQualifiedKey, output:Array):void
		{
			getCoordsFromRecordKey(recordKey, tempPoint);
			
			var bounds:IBounds2D = initBoundsArray(output);
			bounds.includePoint(tempPoint);
			if (isNaN(tempPoint.x))
				bounds.setXRange(-Infinity, Infinity);
			if (isNaN(tempPoint.y))
				bounds.setYRange(-Infinity, Infinity);
		}

		/**
		 * This function returns a Bounds2D object set to the data bounds associated with the background.
		 * @param output A Bounds2D object to store the result in.
		 */
		override public function getBackgroundDataBounds(output:IBounds2D):void
		{
			// use filtered data so data bounds will not include points that have been filtered out.
			if (zoomToSubset.value)
			{
				output.reset();
			}
			else
			{
				output.setBounds(
					statsX.getMin(),
					statsY.getMin(),
					statsX.getMax(),
					statsY.getMax()
				);
			}
		}
	}
}
