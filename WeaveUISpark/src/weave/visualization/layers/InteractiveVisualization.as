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

package weave.visualization.layers
{
	import flash.display.Graphics;
	import flash.display.InteractiveObject;
	import flash.events.ContextMenuEvent;
	import flash.events.Event;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.events.TransformGestureEvent;
	import flash.geom.Point;
	import flash.ui.ContextMenu;
	import flash.ui.Keyboard;
	import flash.ui.Multitouch;
	import flash.ui.MultitouchInputMode;
	
	import spark.components.Group;
	
	import weave.Weave;
	import weave.api.data.IQualifiedKey;
	import weave.api.getSessionState;
	import weave.api.primitives.IBounds2D;
	import weave.api.registerLinkableChild;
	import weave.api.ui.IPlotter;
	import weave.compiler.StandardLib;
	import weave.core.LinkableBoolean;
	import weave.core.LinkableNumber;
	import weave.core.StageUtils;
	import weave.data.KeySets.KeySet;
	import weave.primitives.Bounds2D;
	import weave.primitives.GeometryType;
	import weave.primitives.SimpleGeometry;
	import weave.utils.CustomCursorManager;
	import weave.utils.DrawUtils;
	import weave.utils.ProbeTextUtils;
	import weave.utils.VectorUtils;
	import weave.utils.ZoomUtils;
	
	/**
	 * This is a container for a list of PlotLayers
	 * 
	 * @author adufilie
	 */
	public class InteractiveVisualization extends Visualization
	{
		public static var debug:Boolean = false;
		
		public function InteractiveVisualization()
		{
			doubleClickEnabled = true;
			
			addContextMenuEventListener();
			
			//gesture  - sets for More than one finger [TransformGestureEvent,PressAndTapGestureEvent,GestureEvent]
			//Touch_point - sets for one finger [basic Touch events]
			//none - sets to handle user handle as Mouse events	
			//to-do may require a flag to set the mode
			Multitouch.inputMode = MultitouchInputMode.GESTURE;
		
			addEventListener(TransformGestureEvent.GESTURE_PAN, handleMouseEvent);
			addEventListener(TransformGestureEvent.GESTURE_ZOOM, handleMouseEvent);
			
			addEventListener(MouseEvent.DOUBLE_CLICK, handleDoubleClick);
			addEventListener(MouseEvent.MOUSE_DOWN, handleMouseDown);
			addEventListener(MouseEvent.ROLL_OUT, handleRollOut);
			addEventListener(MouseEvent.ROLL_OVER, handleRollOver);
			addEventListener(MouseEvent.MOUSE_WHEEL,handleMouseWheel);
			
			WeaveAPI.StageUtils.addEventCallback(MouseEvent.MOUSE_MOVE, this, saveMouseMoveEvent);
			WeaveAPI.StageUtils.addEventCallback(StageUtils.THROTTLED_MOUSE_MOVE_EVENT, this, handleThrottledMouseMove);
			WeaveAPI.StageUtils.addEventCallback(MouseEvent.MOUSE_UP, this, handleMouseUp);
			WeaveAPI.StageUtils.addEventCallback(KeyboardEvent.KEY_DOWN, this, handleKeyboardEvent);
			WeaveAPI.StageUtils.addEventCallback(KeyboardEvent.KEY_UP, this, handleKeyboardEvent);
			WeaveAPI.StageUtils.addEventCallback(StageUtils.POINT_CLICK_EVENT, this, _handlePointClick);
		}
		
		override protected function createChildren():void
		{
			super.createChildren();
			
			addElement(selectionCanvas);
		}
		
		private function addContextMenuEventListener():void
		{
			if (WeaveAPI.topLevelApplication == null)
			{
				callLater(addContextMenuEventListener);
				return;
			}
			var contextMenu:ContextMenu = (WeaveAPI.topLevelApplication as InteractiveObject).contextMenu;
			if (!contextMenu)
				return callLater(addContextMenuEventListener);
			contextMenu.addEventListener(ContextMenuEvent.MENU_SELECT, removeCursor);
		}
		private function removeCursor(e:Event):void
		{
			CustomCursorManager.hack_removeCurrentCursor();
		}
		
		public const enableZoomAndPan:LinkableBoolean = registerLinkableChild(this, new LinkableBoolean(true));
		public const enableSelection:LinkableBoolean = registerLinkableChild(this, new LinkableBoolean(true));
		public const enableProbe:LinkableBoolean = registerLinkableChild(this, new LinkableBoolean(true));
		public const zoomFactor:LinkableNumber = registerLinkableChild(this, new LinkableNumber(2, verifyZoomFactor));
		
		private function verifyZoomFactor(value:Number):Boolean
		{
			return value >= 1;
		}
		
		private var activeKeyType:String = null;
		private var gestureActive:Boolean = false;
		private var mouseDragActive:Boolean = false;
		private const selectionCanvas:Group = new Group();
		
		private const mouseDragStageCoords:IBounds2D = new Bounds2D();
		
		private var _mouseMode:String = null;
		
		private function isModeSelection(mode:String):Boolean
		{
			return mode == InteractionController.SELECT_ADD
				|| mode == InteractionController.SELECT
				|| mode == InteractionController.SELECT_REMOVE;
		}
		
		private function isModeZoom(mode:String):Boolean
		{
			return mode == InteractionController.ZOOM
				|| mode == InteractionController.ZOOM_IN
				|| mode == InteractionController.ZOOM_OUT
				|| mode == InteractionController.ZOOM_TO_EXTENT;
		}
		
		
		private function updateMouseMode(inputType:String = null):void
		{
			_mouseMode = Weave.properties.toolInteractions.determineInteraction(inputType);
			
			//weaveTrace('inputType '+inputType+' -> mode ' + _mouseMode);
			
			if (!enableZoomAndPan.value && (isModeZoom(_mouseMode) || _mouseMode == InteractionController.PAN))
			{
				_mouseMode = InteractionController.SELECT;
			}
			if (!enableSelection.value && isModeSelection(_mouseMode))
			{
				if (enableZoomAndPan.value)
					_mouseMode = InteractionController.PAN;
				else
					_mouseMode = null;//Weave.properties.toolInteractions.defaultDragMode.value;
			}
			
			updateMouseCursor();
		}
		
		private function updateMouseCursor():void
		{
			if (mouseIsRolledOver)
			{
				if (_mouseMode == InteractionController.PAN)
				{
					if (WeaveAPI.StageUtils.mouseButtonDown)
						CustomCursorManager.showCursor(CURSOR_HAND_GRAB);
					else
						CustomCursorManager.showCursor(CURSOR_HAND);
				}
				else if (_mouseMode == InteractionController.SELECT_ADD)
				{
					CustomCursorManager.showCursor(CURSOR_SELECT_ADD);
				}
				else if (_mouseMode == InteractionController.SELECT || _mouseMode == InteractionController.PROBE)
				{
					CustomCursorManager.showCursor(CURSOR_SELECT_REPLACE);
				}	
				else if (_mouseMode == InteractionController.SELECT_REMOVE)
				{
					CustomCursorManager.showCursor(CURSOR_SELECT_SUBTRACT);
				}
				else if (_mouseMode == InteractionController.ZOOM)
				{
					CustomCursorManager.showCursor(CURSOR_ZOOM);
				}
			}
		}
		
		private function handleKeyboardEvent():void
		{
			// if the escape key was hit, stop whatever mouse drag operation is in progress
			if (WeaveAPI.StageUtils.keyboardEvent && WeaveAPI.StageUtils.keyboardEvent.keyCode == Keyboard.ESCAPE)
			{
				mouseDragActive = false;			
			}
			
			// if currently dragging, don't change mouse mode
			if (!mouseDragActive)
				updateMouseMode();
		}
		
		/**
		 * This function gets called whenever StageUtils runs point click event callbacks.
		 * This function should remain private.
		 */
		private function _handlePointClick():void
		{
			// only handle the event if the mouse is rolled over
			if (mouseIsRolledOver)
				handleMouseClick(WeaveAPI.StageUtils.mouseEvent);
		}
		
		// this function can be defined with override by extending classes and call super.handleMouseClick(event);
		protected function handleMouseClick(event:MouseEvent):void
		{
			handleMouseEvent(event);
		}
		
		
		protected function handleDoubleClick(event:MouseEvent):void
		{
			handleMouseEvent(event);
		}
		
		private var hack_mouseDownSelectionState:Object = null;
		protected function handleMouseDown(event:MouseEvent):void
		{			
			updateMouseMode(InteractionController.INPUT_DRAG); // modifier keys may have changed just prior to pressing mouse button, so update mode now
			
			//for detecting change between drag start and drag end
			// TEMPORARY HACK - Weave.defaultSelectionKeySet
			hack_mouseDownSelectionState = getSessionState(Weave.defaultSelectionKeySet);
			
			mouseDragActive = true;
			// clear probe when drag starts
			clearProbe();
			// start the selection rectangle from the mouse down point
			// for accuracy, use the stage coordinates from the event, not the current coordinates from the stage
			mouseDragStageCoords.setRectangle(event.stageX, event.stageY, 0, 0);
			updateSelectionCoords(true);
			
			handleMouseEvent(event);
		}
		protected function handleMouseUp():void
		{
			updateMouseCursor();
			
			// when the mouse is released, handle mouse move so the selection rectangle will cause the selection to update.
			handleMouseEvent(WeaveAPI.StageUtils.mouseEvent);
		}
		protected var _lastMouseMoveEvent:MouseEvent;
		protected function saveMouseMoveEvent():void
		{
			_lastMouseMoveEvent = WeaveAPI.StageUtils.mouseEvent;
		}
		protected function handleThrottledMouseMove():void
		{
			if (_lastMouseMoveEvent)
				handleMouseEvent(_lastMouseMoveEvent);
		}
		protected function handleRollOut(event:MouseEvent):void
		{
			if (mouseIsRolledOver)
			{
				CustomCursorManager.hack_removeAllCursors();
				mouseIsRolledOver = false;
				
				// when rolled over goes from true to false, clear the probe
				clearProbe();
			}
			handleMouseEvent(event);
			
			updateMouseCursor();
		}
		protected function handleRollOver(event:MouseEvent):void
		{
			mouseIsRolledOver = true;
			handleMouseEvent(event);
			
			updateMouseCursor();
		}
		
		protected var mouseIsRolledOver:Boolean = false; // start this at false because we don't want tools probing when mouse is not rolled over
		
		private const _tempBounds:IBounds2D = new Bounds2D();
		private const _screenBounds:IBounds2D = new Bounds2D();
		protected function handleMouseWheel(event:MouseEvent):void
		{
			if (Weave.properties.enableMouseWheel.value)
				handleMouseEvent(event);
		}
		
		//handles both MouseEvent and TransformGestureEvent
		protected function handleMouseEvent(event:Event):void
		{
			// determine proper input type
			var inputType:String = null;
			var mouseEvent:MouseEvent = event as MouseEvent;
			var gestureEvent:TransformGestureEvent = event as TransformGestureEvent;
			
			if (debug && gestureEvent)
			{
				weaveTrace(StandardLib.substitute("gesture local({0}) offset({1}) scale({2})", [gestureEvent.localX, gestureEvent.localY], [gestureEvent.offsetX, gestureEvent.offsetY], [gestureEvent.scaleX, gestureEvent.scaleY]));
			}
			
			switch (event.type)
			{
				case MouseEvent.CLICK:
				{
					inputType = InteractionController.INPUT_CLICK;
					break;
				}
				case MouseEvent.DOUBLE_CLICK:
				{
					if (!mouseIsRolledOver)
						return;
					
					inputType = InteractionController.INPUT_DCLICK;
					break;
				}
				case MouseEvent.MOUSE_MOVE:
				case MouseEvent.ROLL_OVER:
				case MouseEvent.ROLL_OUT:
				{
					if (mouseEvent.buttonDown)
						inputType = InteractionController.INPUT_DRAG;
					else
						inputType = InteractionController.INPUT_MOVE;
					
					break;
				}
				case MouseEvent.MOUSE_WHEEL:
				{
					inputType = InteractionController.INPUT_WHEEL;
					break;
				}
				case TransformGestureEvent.GESTURE_PAN:
				{
					inputType = InteractionController.INPUT_PAN;
					break;
				}
				case TransformGestureEvent.GESTURE_ZOOM:
				{
					inputType = InteractionController.INPUT_ZOOM;
					break;
				}
			}
			
			// cancel any active drag if user is gesturing
			if (gestureEvent)
			{
				mouseDragActive = false;
			}
			
			// if currently dragging, update drag coords and don't change mouse mode
			if (mouseDragActive)
			{
				// update end coordinates of selection rectangle				
				if (event.type == MouseEvent.MOUSE_UP)
				{
					// on a mouse up event, we want accuracy, so use the mouse up event coordinates
					mouseDragStageCoords.setMaxCoords(mouseEvent.stageX, mouseEvent.stageY);
				}
				else
				{
					// IMPORTANT: for speed, use the current mouse coordinates instead of the event coordinates
					mouseDragStageCoords.setMaxCoords(stage.mouseX, stage.mouseY);
				}
				if (isModeSelection(_mouseMode))
					updateSelectionCoords();
			}
			else
			{
				// not dragging -- ok to update mouse mode
				updateMouseMode(inputType);
			}
			
			var dragReleased:Boolean = mouseDragActive && !mouseEvent.buttonDown;
			switch (_mouseMode)
			{
				case InteractionController.SELECT_ADD:
				{
					if (mouseDragActive)
						handleSelectionEvent(event, _mouseMode);
					break;
				}
				case InteractionController.SELECT:
				{
				   	if (mouseDragActive)
						handleSelectionEvent(event, _mouseMode);
					break;
				}
				case InteractionController.SELECT_REMOVE:
				{
					if (mouseDragActive)
						handleSelectionEvent(event, _mouseMode);
					break;
				}
				case InteractionController.SELECT_ALL:
				{
					if (mouseIsRolledOver)
						selectAllVisibleRecords();
					break;
				}
				case InteractionController.PAN:
				{
					//weaveTrace(ObjectUtil.toString(event, null, ['target','currentTarget']),'mouseMode '+_mouseMode,'inputType '+inputType);
					
					if (enableZoomAndPan.value)
					{
						if (mouseDragActive || inputType == InteractionController.INPUT_PAN)
						{
							if (gestureEvent)
								mouseDragStageCoords.setRectangle(stage.mouseX, stage.mouseY, gestureEvent.offsetX, gestureEvent.offsetY);
							
							if (debug)
								weaveTrace('pan '+[mouseDragStageCoords.getWidth(), mouseDragStageCoords.getHeight()]);
							
							// pan the dragged distance
							projectDragBoundsToDataQueryBounds(false);
							plotManager.zoomBounds.getDataBounds(tempDataBounds);
							tempDataBounds.offset(-queryBounds.getWidth(), -queryBounds.getHeight());
							plotManager.zoomBounds.setDataBounds(tempDataBounds);
							// set begin point for next pan
							mouseDragStageCoords.getMaxPoint(tempPoint);
							mouseDragStageCoords.setMinPoint(tempPoint);
						}
					}
					break;
				}
				case InteractionController.ZOOM:
				{
					//weaveTrace(ObjectUtil.toString(event, null, ['target','currentTarget']),'mouseMode '+_mouseMode,'inputType '+inputType);
					
					if (enableZoomAndPan.value)
					{
						var zoomValue:Number = 1;
						if (inputType == InteractionController.INPUT_WHEEL)
						{
							if (mouseEvent.delta > 0)
								zoomValue = zoomFactor.value;
							else
								zoomValue = 1 / zoomFactor.value;
						}
						else if (inputType == InteractionController.INPUT_ZOOM)
						{
							//TODO: support separate scaleX and scaleY values (though we haven't witnessed them to be different yet).
							zoomValue = (gestureEvent.scaleX + gestureEvent.scaleY) / 2;
						}
						
						if (zoomValue != 1)
						{
							if (debug)
								weaveTrace('zoom '+zoomValue);
							
							plotManager.zoomBounds.getDataBounds(_tempBounds);
							plotManager.zoomBounds.getScreenBounds(_screenBounds);
							ZoomUtils.zoomDataBoundsByRelativeScreenScale(_tempBounds, _screenBounds, mouseX, mouseY, zoomValue, false);
							plotManager.setCheckedZoomDataBounds(_tempBounds);
						}
						else if (dragReleased)
						{
							// zoom to selected data bounds if area > 0
							projectDragBoundsToDataQueryBounds(true); // data bounds in same direction when zooming
							if (queryBounds.getArea() > 0)
								plotManager.setCheckedZoomDataBounds(queryBounds);
						}	
					}
					break;
				}
				case InteractionController.PROBE:
				{
					if (mouseIsRolledOver)
					{
						// probe when mouse is rolled over and selection is inactive
						doProbe();
					}
					
					break;
				}
				case InteractionController.ZOOM_TO_EXTENT:
				{
					if (enableZoomAndPan.value)
						plotManager.zoomBounds.setDataBounds(plotManager.fullDataBounds, true); // zoom to full extent
					break;
				}
				case InteractionController.ZOOM_IN:
				case InteractionController.ZOOM_OUT:
				{
					if (enableZoomAndPan.value)
					{
						var multiplier:Number = 1;
						if (_mouseMode == InteractionController.ZOOM_IN)
							multiplier = 1 / zoomFactor.value;
						else
							multiplier = zoomFactor.value;
						
						projectDragBoundsToDataQueryBounds(false);
						plotManager.zoomBounds.getDataBounds(_tempBounds);
						_tempBounds.setCenter(queryBounds.getXCenter(), queryBounds.getYCenter());
						
						_tempBounds.centeredResize(_tempBounds.getWidth() * multiplier, _tempBounds.getHeight() * multiplier);
						
						plotManager.setCheckedZoomDataBounds(_tempBounds);
					}
					break;
				}
			}
			
			// finally, unset mouseDragActive if button was released
			if (dragReleased)
			{
				mouseDragActive = false;
			}
			
			updateSelectionRectangleGraphics();
		}
		
		private function selectAllVisibleRecords():void
		{
			// set up mouse drag rectangle to select or deselect visible area
			plotManager.zoomBounds.getScreenBounds(_screenBounds);
			_screenBounds.getMinPoint(tempPoint);
			mouseDragStageCoords.setMinPoint(localToGlobal(tempPoint));
			_screenBounds.getMaxPoint(tempPoint);
			mouseDragStageCoords.setMaxPoint(localToGlobal(tempPoint));
			
			doSelection();
		}
		
		private var _selectionGraphicsCleared:Boolean = true;
		private const _selectionGeometry:SimpleGeometry = new SimpleGeometry();
		private const _selectionPoint:SimpleGeometry = new SimpleGeometry(GeometryType.POINT);
		private var _lassoScreenPoints:Array = [];
		private var _lastLassoPoint:Point = null;
		
		protected function updateSelectionCoords(reset:Boolean = false):void
		{
			if (!isModeSelection(_mouseMode))
				return;
			
			mouseDragStageCoords.getMaxPoint(tempPoint); // stage coords
			var localMaxPoint:Point = selectionCanvas.globalToLocal(tempPoint); // local screen coords
			
			if (reset || _lassoScreenPoints.length == 0)
			{
				mouseDragStageCoords.getMinPoint(tempPoint); // stage coords
				var localMinPoint:Point = selectionCanvas.globalToLocal(tempPoint); // local screen coords
				
				_lassoScreenPoints = [localMinPoint, localMaxPoint];
				_lastLassoPoint = localMaxPoint;
			}
			else if (Math.abs(localMaxPoint.x - _lastLassoPoint.x) >= 5 || Math.abs(localMaxPoint.y - _lastLassoPoint.y) >= 5 )
			{
				// if the new point is far enough away from the previous point, add it to the coords
				_lassoScreenPoints.push(localMaxPoint);
				_lastLassoPoint = localMaxPoint;
			}
		}
		
		protected function updateSelectionRectangleGraphics():void 
		{
			if (!Weave.properties.enableToolSelection.value || !enableSelection.value)
				return;
			
			var g:Graphics = selectionCanvas.graphics;
			if (!_selectionGraphicsCleared)
				g.clear();
			
			if (!mouseDragActive || _mouseMode == InteractionController.PAN)
			{
				_selectionGraphicsCleared = true;
				return;
			}
			
			_selectionGraphicsCleared = false; 
			
			// use a blue rectangle for zoom mode, green for selection
			var lineColor:Number;
			if (_mouseMode == InteractionController.ZOOM)
				lineColor = Weave.properties.dashedZoomColor.value;
			else
				lineColor = Weave.properties.dashedSelectionColor.value;
			
			var dashedLengths:Array = Weave.properties.dashedLengths.getSessionState() as Array;
			
			// init temp bounds for reprojecting coordinates
			plotManager.zoomBounds.getDataBounds(tempDataBounds);
			plotManager.zoomBounds.getScreenBounds(tempScreenBounds);
			
			g.lineStyle(2, lineColor, .75, false, 'normal', 'none');
			if (Weave.properties.selectionMode.value == InteractionController.SELECTION_MODE_RECTANGLE || _mouseMode == InteractionController.ZOOM)
			{
				mouseDragStageCoords.getMinPoint(tempPoint); // stage coords
				var min:Point = selectionCanvas.globalToLocal(tempPoint); // local screen coords
				mouseDragStageCoords.getMaxPoint(tempPoint); // stage coords
				var max:Point = selectionCanvas.globalToLocal(tempPoint); // local screen coords
				
				DrawUtils.drawDashedLine(g, [min, new Point(min.x, max.y), max], dashedLengths);
				DrawUtils.drawDashedLine(g, [min, new Point(max.x, min.y), max], dashedLengths);
			}
			else if (Weave.properties.selectionMode.value == InteractionController.SELECTION_MODE_CIRCLE)
			{
				DrawUtils.drawDashedLine(g, getCircleLocalScreenCoords(), dashedLengths);
			}
			else if (Weave.properties.selectionMode.value == InteractionController.SELECTION_MODE_LASSO)
			{
				var lassoPolygon:Array = _lassoScreenPoints.concat(_lassoScreenPoints[0]);
				DrawUtils.drawDashedLine(g, lassoPolygon, dashedLengths);
				fillPolygon(g, lineColor, 0.05, lassoPolygon);
			}
		}
		
		private function getCircleLocalScreenCoords():Array
		{
			mouseDragStageCoords.getMinPoint(tempPoint); // stage coords
			var localMinPoint:Point = selectionCanvas.globalToLocal(tempPoint); // local screen coords
			mouseDragStageCoords.getMaxPoint(tempPoint); // stage coords
			var localMaxPoint:Point = selectionCanvas.globalToLocal(tempPoint); // local screen coords
			
			var dragWidth:Number = localMaxPoint.x - localMinPoint.x;
			var dragHeight:Number = localMaxPoint.y - localMinPoint.y;

			var direction:Number = -mouseDragStageCoords.getXDirection() || 1;
			var thetaOffset:Number = Math.atan2(dragHeight, dragWidth);
			var radius:Number = Math.sqrt(dragWidth*dragWidth + dragHeight*dragHeight);
			
			const segmentLength:Number = 8; // pixels
			var segmentSpan:Number = segmentLength / radius; // radians
			segmentSpan = Math.min(Math.PI / 4, segmentSpan); // maximum 45 degrees per segment
			// draw the segments
			var segmentCount:Number = Math.ceil(Math.PI * 2 / segmentSpan);
			segmentCount = Math.min(64, segmentCount);
			
			var result:Array = [];
			for (var i:int = 0; i < segmentCount + 1; i++)
			{
				var theta:Number = direction * i * 2 * Math.PI / segmentCount + thetaOffset;
				var _x:Number = localMinPoint.x + radius * Math.cos(theta); // center a + radius x * cos(theta)
				var _y:Number = localMinPoint.y + radius * Math.sin(theta); // center b + radius y * sin(theta)
				result.push(new Point(_x, _y));
			}
			return result;
		}
		
		private function fillPolygon(graphics:Graphics, color:uint, alpha:Number, points:Array):void
		{
			DrawUtils.clearLineStyle(graphics);
			var n:int = points.length;
			for (var i:int = 0; i <= n; i++)
			{
				var point:Point = points[i % n];
				if (i == 0)
				{
					graphics.moveTo(point.x, point.y);
					graphics.beginFill(color, alpha);
				}
				else
					graphics.lineTo(point.x, point.y);
			}
			graphics.endFill();
		}
		
		private function handleSelectionEvent(event:Event, mode:String):void
		{
			// update end coordinates of selection rectangle
			if (event.type == MouseEvent.MOUSE_UP)
			{
				// on a mouse up event, we want accuracy, so use the mouse up event coordinates
				mouseDragStageCoords.setMaxCoords((event as MouseEvent).stageX, (event as MouseEvent).stageY);
			}
			else
			{
				// IMPORTANT: for interaction speed, use the current mouse coordinates instead of the event coordinates.
				// otherwise, queued mouse events will be handled individually and it will feel sluggish
				mouseDragStageCoords.setMaxCoords(stage.mouseX, stage.mouseY);
			}
			
			if ( isModeSelection(mode) )
			{
				// only if selection is enabled
				if (enableSelection.value)
					doSelection();
			}
		}
		private function clearSelection():void
		{
			for each (var name:String in plotManager.plotters.getNames())
				setSelectionKeys(name, null);
		}
		
		/**
		 * This function projects drag start,stop screen coordinates into data coordinates and stores the result in queryBounds.
		 * @param zooming Specify true when computing zoom coordinates.
		 */		
		protected function projectDragBoundsToDataQueryBounds(zooming:Boolean):void
		{
			plotManager.zoomBounds.getDataBounds(tempDataBounds);
			plotManager.zoomBounds.getScreenBounds(tempScreenBounds);
			
			// project stage coords to local layer coords
			mouseDragStageCoords.getMinPoint(tempPoint); // stage coords
			var localMinPoint:Point = globalToLocal(tempPoint); // local screen coords
			mouseDragStageCoords.getMaxPoint(tempPoint); // stage coords
			var localMaxPoint:Point = globalToLocal(tempPoint); // local screen coords
			
			// project screen coords to data coords
			tempScreenBounds.projectPointTo(localMinPoint, tempDataBounds);
			tempScreenBounds.projectPointTo(localMaxPoint, tempDataBounds);
			
			// query the spatial index, set selection
			queryBounds.setMinPoint(localMinPoint);
			queryBounds.setMaxPoint(localMaxPoint);
			
			if (zooming)
			{
				// swap min,max coordinates if necessary
				if (queryBounds.getXDirection() != tempDataBounds.getXDirection())
					queryBounds.setXRange(queryBounds.getXMax(), queryBounds.getXMin());
				if (queryBounds.getYDirection() != tempDataBounds.getYDirection())
					queryBounds.setYRange(queryBounds.getYMax(), queryBounds.getYMin());
				
				// expand rectangle if necessary to match screen aspect ratio
				var xScale:Number = queryBounds.getXCoverage() / tempScreenBounds.getXCoverage();
				var yScale:Number = queryBounds.getYCoverage() / tempScreenBounds.getYCoverage();
				if (xScale > yScale)
					queryBounds.setHeight( queryBounds.getYDirection() * tempScreenBounds.getYCoverage() * xScale );
				if (yScale > xScale)
					queryBounds.setWidth( queryBounds.getXDirection() * tempScreenBounds.getXCoverage() * yScale );
			}
		}
		
		protected function doSelection():void
		{
			if (!parent)
				return;
			
			// don't set a selection or clear the probe keys if selection is disabled
			if (!enableSelection.value)
				return;
			
			plotManager.zoomBounds.getDataBounds(tempDataBounds);
			plotManager.zoomBounds.getScreenBounds(tempScreenBounds);

			// loop from bottom layer to top layer
			layerLoop: for each (var name:String in plotManager.plotters.getNames())
			{
				var plotter:IPlotter = plotManager.plotters.getObject(name) as IPlotter;
				var settings:LayerSettings = plotManager.getLayerSettings(name);
				// skip this layer if it is disabled
				if (!plotManager.layerShouldBeRendered(name) || !settings.selectable.value)
					continue;
				// skip this layer if it does not contain lastProbedQKey
				if (_lastProbedQKeys)
					for each (var key:IQualifiedKey in _lastProbedQKeys)
						if (!plotter.filteredKeySet.containsKey(key))
							continue layerLoop;
				
				// when using the selection layer, clear the probe
				setProbeKeys(name, []);
				projectDragBoundsToDataQueryBounds(false);
				
				// calculate minImportance
				var minImportance:Number = tempDataBounds.getArea() / tempScreenBounds.getArea();
				
				// don't query outside visible data bounds
				if (!tempDataBounds.overlaps(queryBounds))
					continue;
				tempDataBounds.constrainBounds(queryBounds, false);
				
				var keys:Array = null;
				if (Weave.properties.selectionMode.value == InteractionController.SELECTION_MODE_RECTANGLE)
				{
					// if user has probed something and not dragged the mouse during selection, select only the probed shapes
					if (!(_lastProbedQKeys && queryBounds.getWidth() == 0 && queryBounds.getHeight() == 0))
						keys = plotManager.hack_getSpatialIndex(name).getKeysGeometryOverlap(queryBounds, minImportance, false, tempDataBounds);
				}
				else if (Weave.properties.selectionMode.value == InteractionController.SELECTION_MODE_CIRCLE)
				{
					// reproject circle screen coords to data coords
					var coords:Array = getCircleLocalScreenCoords();
					for each (var point:Point in coords)
						tempScreenBounds.projectPointTo(point, tempDataBounds);
					_selectionGeometry.setVertices(coords);
					
					keys = plotManager.hack_getSpatialIndex(name).getKeysGeometryOverlapGeometry(_selectionGeometry, minImportance, false);
				}
				else if (Weave.properties.selectionMode.value == InteractionController.SELECTION_MODE_LASSO)
				{
					// reproject lasso screen coords to data coords
					var lassoDataPoints:Array = [];
					for each (var screenPoint:Point in _lassoScreenPoints)
					{
						var tempDataPoint:Point = screenPoint.clone();
						tempScreenBounds.projectPointTo(tempDataPoint, tempDataBounds);
						lassoDataPoints.push(tempDataPoint);
					}
					_selectionGeometry.setVertices(lassoDataPoints);
					
					keys = plotManager.hack_getSpatialIndex(name).getKeysGeometryOverlapGeometry(_selectionGeometry, minImportance, false);
				}
				
				keys = VectorUtils.flatten(_lastProbedQKeys, keys);
				setSelectionKeys(name, keys);
				
				break; // select only one layer at a time
			}
			
			
			// TEMPORARY HACK - Weave.defaultSelectionKeySet
			var hack_noSelectionChangeSinceMouseDown:Boolean = WeaveAPI.SessionManager.computeDiff(hack_mouseDownSelectionState, getSessionState(Weave.defaultSelectionKeySet)) === undefined;
			
			// if mouse is released and selection hasn't changed since mouse down, clear selection
			if (_mouseMode == InteractionController.SELECT && !WeaveAPI.StageUtils.mouseButtonDown && hack_noSelectionChangeSinceMouseDown)
			{
				clearSelection();
			}
		}
		
		/**
		 * This is the last IQualifiedKey (record identifier) that was probed.
		 */
		public function get lastProbedKey():IQualifiedKey { return _lastProbedQKeys ? _lastProbedQKeys[0] : null; }
		public function get lastProbedKeys():Array { return _lastProbedQKeys; }
		private var _lastProbedQKeys:Array = null;
		
		protected function doProbe():void
		{
			if (!parent || !Weave.properties.enableToolProbe.value || !enableProbe.value)
				return;
			
			// NOTE: this code is hacked to work with only one global probe KeySet
			
			// first reset this
			_lastProbedQKeys = null;
			
			// stop if not rolled over
			if (!mouseIsRolledOver)
				return;
			
			plotManager.zoomBounds.getDataBounds(tempDataBounds);
			plotManager.zoomBounds.getScreenBounds(tempScreenBounds);
			
			// handle probe when mouse hasn't moved since last frame.
			var names:Array = plotManager.plotters.getNames().reverse(); // top to bottom
			var lastActiveLayer:String = null;
			for each (var name:String in names)
			{
				var settings:LayerSettings = plotManager.getLayerSettings(name);
				if (!plotManager.layerShouldBeRendered(name) || !settings.selectable.value)
					continue;
				
				lastActiveLayer = name;
				
				// get data coords from screen coords
				var bufferSize:Number = Weave.properties.probeBufferSize.value; 
				
				queryBounds.setCenteredRectangle(mouseX, mouseY, bufferSize * 2, bufferSize * 2);
				tempScreenBounds.projectCoordsTo(queryBounds, tempDataBounds);
				
				var xPrecision:Number = tempDataBounds.getXCoverage() / tempScreenBounds.getXCoverage();
				var yPrecision:Number = tempDataBounds.getYCoverage() / tempScreenBounds.getYCoverage();
				
				//trace(layers.getName(layer),queryBounds);
				
				// probe for records
				
				if (!tempDataBounds.overlaps(queryBounds))
					continue;
				var keys:Array = plotManager.hack_getSpatialIndex(name).getClosestOverlappingKeys(queryBounds, xPrecision, yPrecision, tempDataBounds);
				//trace(layers.getName(layer),keys);
				
				// stop when we find keys
				if (keys.length > 0)
				{
					setProbeKeys(name, keys);
					_lastProbedQKeys = keys;
					break; // success
				}
			}
			
			if (!_lastProbedQKeys)
			{
				// clear keys if nothing was probed
				// NOTE: this code is hacked to work with only one global probe KeySet
				if (lastActiveLayer)
					setProbeKeys(lastActiveLayer, []);
			}
		}
		
		protected function setSelectionKeys(layerName:String, keys:Array):void
		{
			if (!Weave.properties.enableToolSelection.value || !enableSelection.value)
				return;
			
			// set the probe filter to a new set of keys
			var settings:LayerSettings = plotManager.getLayerSettings(layerName);
			var keySet:KeySet = settings.selectionFilter.internalObject as KeySet;
			if (!keySet)
				return;
			if (!keys)
				keySet.clearKeys();
			else if (_mouseMode == InteractionController.SELECT_ADD)
				keySet.addKeys(keys);
			else if (_mouseMode == InteractionController.SELECT_REMOVE)
				keySet.removeKeys(keys);
			else
				keySet.replaceKeys(keys);
		}
		
		protected function setProbeKeys(layerName:String, keys:Array):void
		{
			//trace("setProbeKeys()",keys);
			// set the probe filter to a new set of keys
			var settings:LayerSettings = plotManager.getLayerSettings(layerName);
			var keySet:KeySet = settings.probeFilter.internalObject as KeySet;
			
			if (keySet != null)
			{
				keySet.replaceKeys(keys);
				
				if (keys.length == 0)
				{
					ProbeTextUtils.hideProbeToolTip();
				}
				else
				{
					var text:String = ProbeTextUtils.getProbeText(keySet.keys, additionalProbeColumns);
					ProbeTextUtils.showProbeToolTip(text, stage.mouseX, stage.mouseY);
				}
			}
		}

		/**
		 * An array of additional columns (or ILinkableHashMaps containing columns) to be displayed in the probe tooltip for this visualization instance 
		 */		
		public var additionalProbeColumns:Array = null;
		
		protected function clearProbe():void
		{
			// don't clear the probe if selection is disabled
			if (!enableSelection.value)
				return;
			
			for each (var name:String in plotManager.layerSettings.getNames())
				setProbeKeys(name, emptyArray);
		}
		private const emptyArray:Array = [];
		protected const queryBounds:IBounds2D = new Bounds2D(); // reusable temporary object
		protected const tempDataBounds:IBounds2D = new Bounds2D(); // reusable temporary object
		protected const tempScreenBounds:IBounds2D = new Bounds2D(); // reusable temporary object
		private const tempPoint:Point = new Point(); // reusable temporary object

		
		/**
		 * This function projects data coordinates to stage coordinates.
		 * @return The point containing the stageX and stageY.
		 */		
		public function getStageCoordinates(dataX:Number, dataY:Number):Point
		{
			tempPoint.x = dataX;
			tempPoint.y = dataY;
			plotManager.zoomBounds.getScreenBounds(tempScreenBounds);
			plotManager.zoomBounds.getDataBounds(tempDataBounds);
			tempDataBounds.projectPointTo(tempPoint, tempScreenBounds);
			
			return localToGlobal(tempPoint);
		}
		
		/**
		 * Get the <code>mouseX</code> and <code>mouseY</code> properties of the container
		 * projected into data coordinates for the container. 
		 * @return The point containing the projected mouseX and mouseY.
		 */
		public function getMouseDataCoordinates():Point
		{
			tempPoint.x = mouseX;
			tempPoint.y = mouseY;
			plotManager.zoomBounds.getScreenBounds(tempScreenBounds);
			plotManager.zoomBounds.getDataBounds(tempDataBounds);
			tempScreenBounds.projectPointTo(tempPoint, tempDataBounds);
			
			return tempPoint;
		}
		
		/**
		 * Embedded cursors
		 */
		public static const CURSOR_LINK:String = "linkCursor";
		[Embed(source="/weave/resources/images/axisLinkCursor.png")]
		private static var linkCursor:Class;
		CustomCursorManager.registerEmbeddedCursor(CURSOR_LINK, linkCursor, 0, 0);
		
		public static const CURSOR_HAND:String = "handCursor";
		[Embed(source="/weave/resources/images/cursor_hand.png")]
		public static var handCursor:Class;
		CustomCursorManager.registerEmbeddedCursor(CURSOR_HAND, handCursor, 1, 2);
		
		public static const CURSOR_HAND_GRAB:String = "handGrabCursor";
		[Embed(source="/weave/resources/images/cursor_grab.png")]
		private static var handGrabCursor:Class;
		CustomCursorManager.registerEmbeddedCursor(CURSOR_HAND_GRAB, handGrabCursor,  1,  2);
		
		public static const CURSOR_SELECT_REPLACE:String = "selectReplaceCursor";
		[Embed(source="/weave/resources/images/cursor_select_replace.png")]
		private static var selectReplaceCursor:Class;
		CustomCursorManager.registerEmbeddedCursor(CURSOR_SELECT_REPLACE,  selectReplaceCursor,  1, 2);
		
		public static const CURSOR_SELECT_ADD:String = "selectAddCursor";
		[Embed(source="/weave/resources/images/cursor_select_add.png")]
		private static var selectAddCursor:Class;
		CustomCursorManager.registerEmbeddedCursor(CURSOR_SELECT_ADD, selectAddCursor, 1, 2);
		
		public static const CURSOR_SELECT_SUBTRACT:String = "selectSubtractCursor";
		[Embed(source="/weave/resources/images/cursor_select_subtract.png")]
		private static var selectSubtractCursor:Class;
		CustomCursorManager.registerEmbeddedCursor(CURSOR_SELECT_SUBTRACT, selectSubtractCursor, 1, 2);
		
		public static const CURSOR_ZOOM:String = "zoomCursor";
		[Embed(source="/weave/resources/images/cursor_zoom.png")]
		private static var zoomCursor:Class;
		CustomCursorManager.registerEmbeddedCursor(CURSOR_ZOOM, zoomCursor, 0, 0);
	}
}
