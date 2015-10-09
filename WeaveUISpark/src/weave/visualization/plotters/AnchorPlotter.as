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
	import flash.display.Shape;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.utils.Dictionary;
	
	import net.ivank.voronoi.VEdge;
	import net.ivank.voronoi.Voronoi;
	
	import weave.Weave;
	import weave.api.data.IQualifiedKey;
	import weave.api.newDisposableChild;
	import weave.api.primitives.IBounds2D;
	import weave.api.registerLinkableChild;
	import weave.api.ui.ILineStyle;
	import weave.api.ui.IPlotTask;
	import weave.api.ui.IPlotter;
	import weave.api.ui.ITextPlotter;
	import weave.core.LinkableBoolean;
	import weave.core.LinkableHashMap;
	import weave.core.LinkableNumber;
	import weave.data.AttributeColumns.BinnedColumn;
	import weave.data.AttributeColumns.ColorColumn;
	import weave.data.BinningDefinitions.CategoryBinningDefinition;
	import weave.data.KeySets.KeySet;
	import weave.primitives.Bounds2D;
	import weave.primitives.ColorRamp;
	import weave.utils.BitmapText;
	import weave.utils.LinkableTextFormat;
	import weave.visualization.plotters.styles.SolidFillStyle;
	import weave.visualization.plotters.styles.SolidLineStyle;

	/**
	 * AnchorPlotter
	 * @author kmanohar
	 */	
	public class AnchorPlotter extends AbstractPlotter implements ITextPlotter
	{
		public function AnchorPlotter()	
		{
			registerLinkableChild(this, LinkableTextFormat.defaultTextFormat); // this causes a redraw when text format changes
			registerLinkableChild(this, Weave.defaultColorColumn);			
			setSingleKeySource(_keySet);
		}
		
		public function setRadViz(radviz:IPlotter):void
		{
			if (this._radviz)
				throw new Error("radviz plotter may only be set once.");
			_radviz = radviz;
			if (radviz is RadVizPlotter)
				anchors = (radviz as RadVizPlotter).anchors;
			if (radviz is CompoundRadVizPlotter)
				anchors = (radviz as CompoundRadVizPlotter).anchors;
			if (!anchors)
				throw new Error("not a radviz plotter");
			this.anchors = registerSpatialProperty(anchors);
			this.anchors.childListCallbacks.addGroupedCallback(this, handleAnchorsChange, true);
			spatialCallbacks.triggerCallbacks();
		}
		private var _radviz:IPlotter;
		private var anchors:LinkableHashMap = null;
		
		public const labelAngleRatio:LinkableNumber = registerSpatialProperty(new LinkableNumber(0, verifyLabelAngleRatio));
		
		private const _keySet:KeySet = newDisposableChild(this, KeySet);
		private const tempPoint:Point = new Point();
		private const _bitmapText:BitmapText = new BitmapText();
		private var coordinate:Point = new Point();//reusable object
		public const enableWedgeColoring:LinkableBoolean = registerLinkableChild(this, new LinkableBoolean(false), fillColorMap);
		public const colorMap:ColorRamp = registerLinkableChild(this, new ColorRamp(ColorRamp.getColorRampXMLByName("Paired")),fillColorMap);
		public var anchorColorMap:Dictionary;
		public const wordWrap:LinkableNumber = registerLinkableChild(this, new LinkableNumber(200));
		
		
		public var drawingClassLines:Boolean = false;//this divides the circle into sectors which represent classes (number of sectors = number of classes)


		// anchorClasses key is String, value is array of AnchorPoint names
		public var anchorClasses:Dictionary = null;//this tells us the classes to which dimensional anchors belong to

		public var anchorThreshold:Number;
		public var doCDLayout:Boolean = false;// this displays the tstat value with every dimensional anchor name (displayed only when CD layout is done)
		public var doCDLayoutMetric:Boolean = true; // ToDo yenfu whether display metric info
		
		private function getClassFromAnchor(anchorName:String):String
		{
			for (var key:String in anchorClasses)
			{
				var anchors:Array = anchorClasses[key];
				if (anchors.indexOf(anchorName) >= 0)
					return key;
			}
			return null;
		}
		
		//Fill this hash map with bounds of every record key for efficient look up in getDataBoundsFromRecordKey
		private var keyBoundsMap:Dictionary = new Dictionary();
		private const _currentScreenBounds:Bounds2D = new Bounds2D();
		private const _currentDataBounds:Bounds2D = new Bounds2D();
		
		public const circleLineStyle:SolidLineStyle = registerLinkableChild(this, new SolidLineStyle());
		public const anchorLineStyle:SolidLineStyle = registerLinkableChild(this, new SolidLineStyle());
		public const anchorFillStyle:SolidFillStyle = registerLinkableChild(this, new SolidFillStyle());
		public const anchorRadius:LinkableNumber = registerLinkableChild(this, new LinkableNumber(5));
		
		public const unrestrictAnchors:LinkableBoolean = registerLinkableChild(this, new LinkableBoolean(false));
		
		public const showBarycenter:LinkableBoolean = registerLinkableChild(this, new LinkableBoolean(false));
		public const barycenterRadius:LinkableNumber = registerLinkableChild(this, new LinkableNumber(5));
		public const barycenterFillStyle:SolidFillStyle = registerLinkableChild(this, new SolidFillStyle());
		public const barycenterLineStyle:SolidLineStyle = registerLinkableChild(this, new SolidLineStyle());
		
		public const showVoronoi:LinkableBoolean = registerLinkableChild(this, new LinkableBoolean(false));
		public const showConvexHull:LinkableBoolean = registerLinkableChild(this, new LinkableBoolean(false));
		
		public function handleAnchorsChange():void
		{
			var keys:Array = anchors.getNames(AnchorPoint);
			var keyArray:Array = WeaveAPI.QKeyManager.getQKeys(ANCHOR_KEYTYPE,keys);

			_keySet.replaceKeys(keyArray);
			fillColorMap();
		}
		
		private static const ANCHOR_KEYTYPE:String = 'dimensionAnchors';
		
		
		
		private function fillColorMap():void
		{
			anchorColorMap = new Dictionary(true);
			var _names:Array = anchors.getNames(AnchorPoint);
			for (var i:int = 0; i < _names.length; i++)
				anchorColorMap[_names[i]] = colorMap.getColorFromNorm(i / (_names.length - 1)); 
		}
		
		override public function drawPlotAsyncIteration(task:IPlotTask):Number
		{
			drawAll(task.recordKeys, task.dataBounds, task.screenBounds, task.buffer);
			return 1;
		}
		private function drawAll(recordKeys:Array, dataBounds:IBounds2D, screenBounds:IBounds2D, destination:BitmapData):void
		{
			var x:Number; 
			var y:Number;
			
			var anchor:AnchorPoint;
			var radians:Number;
			keyBoundsMap = new Dictionary();

			var graphics:Graphics = tempShape.graphics;
			graphics.clear();
									
			
			for each(var key:IQualifiedKey in recordKeys)
			{
				anchor = anchors.getObject(key.localName) as AnchorPoint;
				if (key.keyType != ANCHOR_KEYTYPE || !anchor)
					continue;
				
				anchorLineStyle.beginLineStyle(null, graphics);
				anchorFillStyle.beginFillStyle(null, graphics);

				if(anchorThreshold)
				{
					if(anchor.classDiscriminationMetric.value < anchorThreshold)
						continue;
					
				}
				
				x = anchor.x.value;
				y = anchor.y.value;
				radians = anchor.polarRadians.value;
				var radius:Number = anchor.radius.value;
				
				var cos:Number = Math.cos(radians);
				var sin:Number = Math.sin(radians);
				
				tempPoint.x = radius * cos;
				tempPoint.y = radius * sin;
				dataBounds.projectPointTo(tempPoint, screenBounds);
				
				// draw circle
				if(enableWedgeColoring.value)
					graphics.beginFill(anchorColorMap[key.localName]);
				else if (doCDLayout)
				{
					//color the dimensional anchors according to the class they belong to
					var classStr:String = getClassFromAnchor(key.localName);
					var cc:ColorColumn = Weave.defaultColorColumn;
					var binColumn:BinnedColumn = cc.getInternalColumn() as BinnedColumn;
					binColumn.binningDefinition.requestLocalObject(CategoryBinningDefinition, false)
					var binIndex:int = binColumn.getBinIndexFromDataValue(classStr);
					var color:Number = cc.ramp.getColorFromNorm(binIndex / (binColumn.numberOfBins - 1));
					if (isFinite(color))
						graphics.beginFill(color);
				}
				graphics.drawCircle(tempPoint.x, tempPoint.y, anchorRadius.value);				
				graphics.endFill();
				
				
				
				_bitmapText.trim = false;
				_bitmapText.text = " " + anchor.title.value + " ";
				
				if(doCDLayout && doCDLayoutMetric)//displays the class discrimination metric used, either tstat or pvalue
					_bitmapText.text = _bitmapText.text + "\n"+ "  Metric : " + 
						Math.round(anchor.classDiscriminationMetric.value *100)/100 +"\n" + "  Class :" + anchor.classType.value;
				_bitmapText.verticalAlign = BitmapText.VERTICAL_ALIGN_MIDDLE;
				
				_bitmapText.angle = screenBounds.getYDirection() * (radians * 180 / Math.PI);
				_bitmapText.angle = (_bitmapText.angle % 360 + 360) % 360;
				if (cos > -0.000001) // the label exactly at the bottom will have left align
				{
					_bitmapText.horizontalAlign = BitmapText.HORIZONTAL_ALIGN_LEFT;
					// first get values between -90 and 90, then multiply by the ratio
					_bitmapText.angle = ((_bitmapText.angle + 90) % 360 - 90) * labelAngleRatio.value;
				}
				else
				{
					_bitmapText.horizontalAlign = BitmapText.HORIZONTAL_ALIGN_RIGHT;
					// first get values between -90 and 90, then multiply by the ratio
					_bitmapText.angle = (_bitmapText.angle - 180) * labelAngleRatio.value;
				}
				
				LinkableTextFormat.defaultTextFormat.copyTo(_bitmapText.textFormat);				
				_bitmapText.x = tempPoint.x;
				_bitmapText.y = tempPoint.y;
				_bitmapText.maxWidth = wordWrap.value;
				
				// draw almost-invisible rectangle behind text
				/*_bitmapText.getUnrotatedBounds(_tempBounds);
				_tempBounds.getRectangle(_tempRectangle);				
				destination.fillRect(_tempRectangle, 0x02808080);*/
				
				// draw bitmap text
				_bitmapText.draw(destination);								
			}
			
			destination.draw(tempShape);
			
			if (showBarycenter.value)
			{
				drawBarycenter(recordKeys, dataBounds, screenBounds, destination);
			}
			if (showVoronoi.value)
			{
				drawVoronoi(recordKeys, dataBounds, screenBounds, destination);
			}
			if (showConvexHull.value)
			{
				drawConvexHull(recordKeys, dataBounds, screenBounds, destination);
			}
			
			_currentScreenBounds.copyFrom(screenBounds);
			_currentDataBounds.copyFrom(dataBounds);
		}
		
		
		/**
		 * This function draws the background graphics for this plotter, if applicable.
		 * An example background would be the origin lines of an axis.
		 * @param dataBounds The data coordinates that correspond to the given screenBounds.
		 * @param screenBounds The coordinates on the given sprite that correspond to the given dataBounds.
		 * @param destination The sprite to draw the graphics onto.
		 */
		override public function drawBackground(dataBounds:IBounds2D, screenBounds:IBounds2D, destination:BitmapData):void
		{
			super.drawBackground(dataBounds,screenBounds,destination);
			var g:Graphics = tempShape.graphics;
			g.clear();
			
			coordinate.x = -1;
			coordinate.y = -1;
			
			
			dataBounds.projectPointTo(coordinate, screenBounds);
			var x:Number = coordinate.x;
			var y:Number = coordinate.y;
			coordinate.x = 1;
			coordinate.y = 1;
			dataBounds.projectPointTo(coordinate, screenBounds);
			
			// draw RadViz circle
			if(unrestrictAnchors.value)
					return;

			try {
				circleLineStyle.beginLineStyle(null,g);
				g.drawEllipse(x, y, coordinate.x - x, coordinate.y - y);
			} catch (e:Error) { }
			destination.draw(tempShape);
			
			if(drawingClassLines)
			{
				drawClassLines(dataBounds, screenBounds, destination );
			}
			
			_currentScreenBounds.copyFrom(screenBounds);
			_currentDataBounds.copyFrom(dataBounds);
		}
		
		public function drawClassLines(dataBounds:IBounds2D, screenBounds:IBounds2D, destination:BitmapData):void
		{
			var graphics:Graphics = static_tempShape.graphics;
			graphics.clear();
			var numOfClasses:int = 0;
			for ( var type:Object in anchorClasses)
			{
				numOfClasses++;
			}
			
			var classTheta:Number = (2 * Math.PI)/ numOfClasses;
			var classIncrementor:Number = 0; 
			var centre:Point = new Point();
			centre.x = 0; centre.y = 0;
			dataBounds.projectPointTo(centre, screenBounds);//projecting the centre of the Radviz circle
			
			for(var cdClass:Object in anchorClasses)
			{
				_bitmapText.text = "";
				var previousClassAnchor:Point = new Point();
				var classLabelPoint:Point = new Point();
				var currentClassPos:Number = classTheta * classIncrementor;
				previousClassAnchor.x = Math.cos(currentClassPos);
				previousClassAnchor.y = Math.sin(currentClassPos);
				dataBounds.projectPointTo(previousClassAnchor,screenBounds);
				
				var nextClassAnchor:Point = new Point();
				var nextClassPos:Number = (classTheta - 0.02)  * (classIncrementor + 1);
				nextClassAnchor.x = Math.cos(nextClassPos);
				nextClassAnchor.y = Math.sin(nextClassPos);
				dataBounds.projectPointTo(nextClassAnchor, screenBounds);
				
				graphics.lineStyle(2, 0xb8860B, .4);
				//graphics.lineStyle(2,Math.random() * uint.MAX_VALUE);
				classIncrementor ++;
				graphics.moveTo(previousClassAnchor.x, previousClassAnchor.y);
				graphics.lineTo(centre.x, centre.y);
				//graphics.lineTo(nextClassAnchor.x, nextClassAnchor.y);
				
				//adding class labels TO DO find a way of displaying class labels using legend or labels
				/*var classLabelPosition:Number = (classTheta/2)*classIncrementor;
				classLabelPoint.x = Math.cos(classLabelPosition);
				classLabelPoint.y = Math.sin(classLabelPosition);
				dataBounds.projectPointTo(classLabelPoint, screenBounds);
				
				_bitmapText.text = String(cdClass);
				_bitmapText.x = classLabelPoint.x;
				_bitmapText.y = classLabelPoint.y;
				
				_bitmapText.draw(destination);*/
			}
			destination.draw(static_tempShape);
		}
		
		public function drawBarycenter(recordKeys:Array, dataBounds:IBounds2D, screenBounds:IBounds2D, destination:BitmapData):void
		{
			var graphics:Graphics = static_tempShape.graphics;
			graphics.clear();
			
			var barycenter:Point = new Point();
			var counter:int = 0;
			var anchor:AnchorPoint;
			
			// don't draw anything if there are no anchors.
			if (!recordKeys || !recordKeys.length)
				return;
			
			for each(var key:IQualifiedKey in recordKeys)
			{
				anchor = anchors.getObject(key.localName) as AnchorPoint;
				if (key.keyType != ANCHOR_KEYTYPE || !anchor)
					continue;
				
				barycenter.x += anchor.x.value;
				barycenter.y += anchor.y.value;
				counter++;
			}
			
			barycenter.x = barycenter.x / counter;
			barycenter.y = barycenter.y / counter;
			
			barycenterLineStyle.beginLineStyle(null, graphics);
			barycenterFillStyle.beginFillStyle(null, graphics);
			
			dataBounds.projectPointTo(barycenter, screenBounds);
			
			graphics.drawCircle(barycenter.x, barycenter.y, barycenterRadius.value);
			
			graphics.endFill();
			destination.draw(static_tempShape);
		}
		
		public function drawConvexHull(recordKeys:Array, dataBounds:IBounds2D, screenBounds:IBounds2D, destination:BitmapData):void
		{
			static_drawConvexHull(anchors, circleLineStyle, recordKeys, dataBounds, screenBounds, destination);
		}
		
		private static const static_tempShape:Shape = new Shape();
		public static function static_drawConvexHull(anchors:LinkableHashMap, lineStyle:ILineStyle, recordKeys:Array, dataBounds:IBounds2D, screenBounds:IBounds2D, destination:BitmapData):void
		{
			var graphics:Graphics = static_tempShape.graphics;
			var anchor1:AnchorPoint;
			var anchor2:AnchorPoint;
			var anchor:AnchorPoint;
			var _anchors:Array = [];
			var index:int;
			var p1:Point = new Point();
			var p2:Point = new Point();
			
			graphics.clear();
			if (recordKeys)
			{
				
				// convert the array of record keys into array of anchors
				for(index = 0; index < recordKeys.length; index++)
				{
					anchor = anchors.getObject(recordKeys[index].localName) as AnchorPoint;
					
					if (recordKeys[index].keyType != ANCHOR_KEYTYPE || !anchor)
						continue;
					
					_anchors.push(anchor);
				}
			}
			else
				_anchors = anchors.getObjects();
			
			// don't draw anything if no anchors
			if (_anchors.length == 0)
				return;
			
			// sort by polar angle
			_anchors.sort(anchorCompareFunctionByPolarAngle);
			
			// draw convex hull
			for(index = 0; index < _anchors.length - 1; index++)
			{
				anchor1 = _anchors[index];
				anchor2 = _anchors[index + 1];
				p1.x = anchor1.x.value; p1.y = anchor1.y.value;
				p2.x = anchor2.x.value;p2.y = anchor2.y.value;
				dataBounds.projectPointTo(p1, screenBounds);
				dataBounds.projectPointTo(p2, screenBounds);
				lineStyle.beginLineStyle(null, graphics);
				graphics.moveTo(p1.x, p1.y);
				graphics.lineTo(p2.x, p2.y);				
			}
			
			// draw the last connecting line between the last anchor and the first one.
			p1.x = _anchors[_anchors.length - 1].x.value; p1.y = _anchors[_anchors.length - 1].y.value;
			p2.x = _anchors[0].x.value; p2.y = _anchors[0].y.value;
			
			dataBounds.projectPointTo(p1, screenBounds);
			dataBounds.projectPointTo(p2, screenBounds);
			graphics.moveTo(p1.x, p1.y);
			graphics.lineTo(p2.x, p2.y);
			
			graphics.endFill();
			destination.draw(static_tempShape);
			
			function anchorCompareFunctionByPolarAngle(a1:AnchorPoint, a2:AnchorPoint):Number
			{
				if(a1.polarRadians.value < a2.polarRadians.value)
				{
					return -1;
				} else if (a1.polarRadians.value > a2.polarRadians.value)
				{
					return 1;
				} else {
					return 0;
				}
			}
			
		}
		
		
		
		public function drawVoronoi(recordKeys:Array, dataBounds:IBounds2D, screenBounds:IBounds2D, destination:BitmapData):void
		{
			// http://blog.ivank.net/voronoi-diagram-in-as3.html
			var graphics:Graphics = static_tempShape.graphics;
			graphics.clear();
			
			var i:int;
			var edges:Vector.<VEdge>; // vector  for edges
			var v:Voronoi = new Voronoi();
			var vertices:Vector.<Point> = new Vector.<Point>();
			
			var counter:int = 0;
			
			var barycenter:Point = new Point();
			
			var anchor:AnchorPoint;
			
			// don't draw anything if there are no anchors.
			if (!recordKeys || !recordKeys.length)
				return;
			
			for each(var key:IQualifiedKey in recordKeys)
			{
				anchor = anchors.getObject(key.localName) as AnchorPoint;
				if (key.keyType != ANCHOR_KEYTYPE || !anchor)
					continue;
				
				barycenter.x += anchor.x.value;
				barycenter.y += anchor.y.value;
				var p:Point = new Point(anchor.x.value, anchor.y.value);
				dataBounds.projectPointTo(p, screenBounds);
				vertices.push(p);
				p.x += 0.0000001 * vertices.length;
				p.y += 0.0000001 * vertices.length;
				counter++;
			}
			
			barycenter.x = barycenter.x / counter;
			barycenter.y = barycenter.y / counter;
			dataBounds.projectPointTo(barycenter, screenBounds);
			
			vertices.push(barycenter);

			edges = v.GetEdges(vertices, screenBounds.getWidth(), screenBounds.getHeight());
			
			graphics.lineStyle(1, 0x888888);
			for(i = 0; i< edges.length; i++)
			{
			   graphics.moveTo(edges[i].start.x, edges[i].start.y);
			   graphics.lineTo(edges[i].end  .x, edges[i].end  .y);
			}
			destination.draw(static_tempShape);
		}
		
		override public function getDataBoundsFromRecordKey(recordKey:IQualifiedKey, output:Array):void
		{
			if (anchors)
			{
				var bounds:IBounds2D = initBoundsArray(output);
				var anchor:AnchorPoint = anchors.getObject(recordKey.localName) as AnchorPoint;
				if (anchor)
					bounds.includeCoords(anchor.x.value, anchor.y.value);
			}
			else
				initBoundsArray(output, 0);
		}
		
		override public function getBackgroundDataBounds(output:IBounds2D):void
		{
			output.setBounds(-1, -1.1, 1, 1.1);
		}
		
		private function verifyLabelAngleRatio(value:Number):Boolean
		{
			return 0 <= value && value <= 1;
		}
		
		private var _matrix:Matrix = new Matrix();
		private const _tempBounds:Bounds2D = new Bounds2D();
		private var _tempRectangle:Rectangle = new Rectangle();
		
		private function drawRectangle(graphics:Graphics,destination:BitmapData):void
		{
			_bitmapText.getUnrotatedBounds(_tempBounds);			
			_tempBounds.getRectangle(_tempRectangle);
			
			//graphics.drawRect(_tempRectangle.x, _tempRectangle.y, _tempRectangle.width, _tempRectangle.height);
			
			destination.fillRect(_tempRectangle,  0x02808080);
			return;
			var height:Number = _tempBounds.getWidth();
			var width:Number = _tempBounds.getHeight();
			
			/*_tempBounds.getRectangle(_tempRectangle);
			var p1:Point = new Point();
			_tempBounds.getMinPoint(p1);
			var p2:Point = new Point(_tempBounds.xMin, _tempBounds.yMax);
			var p3:Point = new Point();
			_tempBounds.getMaxPoint(p3);
			var p4:Point = new Point(_tempBounds.xMax, _tempBounds.yMin);
			var angle:Number = _bitmapText.angle;
			angle = angle * Math.PI/180;
			var p:Point = new Point();
			_tempBounds.getMinPoint(p);
						
			graphics.moveTo(p1.x,p1.y);
			graphics.lineTo(p2.x,p2.y);
			graphics.moveTo(p2.x,p2.y);
			graphics.lineTo(p3.x,p3.y);
			graphics.moveTo(p3.x,p3.y);
			graphics.lineTo(p4.x,p4.y);
			graphics.moveTo(p4.x,p4.y);
			graphics.lineTo(p1.x,p1.y);*/
			//graphics.drawRect(rect.x, rect.y, rect.width, rect.height);
		}		
		public function rotatePoint(p:Point, o:Point, d:Number):Point{
			
			var np:Point = new Point();
			p.x += (0 - o.x);
			p.y += (0 - o.y);
			np.x = (p.x * Math.cos(d)) - (p.y * Math.sin(d));
			np.y = Math.sin(d) * p.x + Math.cos(d) * p.y;
			np.x += (0 + o.x);
			np.y += (0 + o.y)
			
			return np;
			
		}
	}	
}