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

package weave.ui
{
	import flash.events.Event;
	import flash.utils.getTimer;
	
	import mx.core.UIComponent;
	
	import weave.api.core.ILinkableObject;
	import weave.compiler.StandardLib;

	/**
	 * This is a component that shows a busy animation.
	 * It will animate automatically when added to the stage.
	 * It will not animate when the <code>visible</code> property is set to false.
	 * 
	 * @author adufilie
	 */
	public class BusyIndicator extends UIComponent
	{
		public function BusyIndicator(target:ILinkableObject = null, ...moreTargets)
		{
			super();
			if (target)
				moreTargets.unshift(target);
			this.targets = moreTargets;
			includeInLayout = false;
			mouseChildren = false;
			addEventListener(Event.FRAME_CONSTRUCTED, render);
		}
		
		/**
		 * This is an Array of ILinkableObjects whose busy status should be monitored.
		 */		
		public var targets:Array; /* of ILinkableObject */
		
		public var fps:Number = 12;//24;
		public var bgColor:uint = 0x000000
		public var bgAlpha:Number = 0x000000
		public var colorSwitchTime:Number = 1; // number of revolutions between color switch
		public var colorStartList:Array = [0xa0a0a0, 0x404040, 0xa0a0a0];
		public var colorEndList:Array = [0xa0a0a0, 0x404040, 0xa0a0a0];
		public var alphaStart:Number = 1;
		public var alphaEnd:Number = 0;
		private var _diameter:Number = 20; // when this is set, diameterRatio will be disabled
		private var _diameterRatio:Number = NaN; // percentage of window size
		public var circleRatio:Number = 0.2;
		public var numCircles:uint = 12;
		private var prevFrame:int = -1;
		private var timeBecameBusy:int = 0;
		public var autoVisibleDelay:int = 2500;
		
		/**
		 * Diameter of busy indicator.
		 * Setting this unsets diameterRatio.
		 */		
		public function set diameter(value:Number):void
		{
			if (isFinite(value))
			{
				_diameter = value;
				_diameterRatio = NaN;
			}
		}
		public function get diameter():Number
		{
			return _diameter;
		}
		
		/**
		 * Diameter expressed as a percentage of the parent size (number between 0 and 1).
		 * Setting this unsets diameter.
		 */		
		public function set diameterRatio(value:Number):void
		{
			if (isFinite(value))
			{
				_diameterRatio = value;
				_diameter = NaN;
			}
		}
		public function get diameterRatio():Number
		{
			return _diameterRatio;
		}
		
		/**
		 * This will update the graphics immediately when set.
		 */
		override public function set visible(value:Boolean):void
		{
			super.visible = value;
			render();
		}
		
		/**
		 * This will automatically toggle visibility based the target's busy status.
		 */
		private function toggleVisible():void
		{
			var busy:Boolean = false;
			for each (var target:ILinkableObject in targets)
			{
				if (WeaveAPI.SessionManager.linkableObjectIsBusy(target))
				{
					busy = true;
					break;
				}
			}
			if (visible != busy)
			{
				if (busy)
				{
					if (timeBecameBusy == -1)
						timeBecameBusy = getTimer();
					if (getTimer() - timeBecameBusy < autoVisibleDelay)
						return;
				}
				
				visible = busy;
			}
			timeBecameBusy = -1;
		}
		
		/**
		 * This will update the graphics.
		 */
		private function render(e:Event=null):void
		{
			if (!stage)
				return;
			
			if (targets && targets.length)
				toggleVisible();
			
			if (!visible)
				return;
			
			var frame:Number = (fps * getTimer() / 1000);
			
			if (prevFrame == int(frame))
				return;
			
			prevFrame = int(frame);
			
			var cx:Number = parent.width / 2 - this.x;
			var cy:Number = parent.height / 2 - this.y;
			var radius:Number;
			if (isFinite(diameter))
				radius = diameter / 2;
			else
				radius = Math.min(parent.width, parent.height) * diameterRatio / 2;
			var revolution:Number = frame / numCircles;
			var colorIndexNorm:Number = revolution % (colorStartList.length - 1) / (colorStartList.length - 1);
			var colorStart:Number = StandardLib.interpolateColor(colorIndexNorm, colorStartList);
			var colorEnd:Number = StandardLib.interpolateColor(colorIndexNorm, colorEndList);
			var step:int = frame % numCircles;
			var angle:Number = Math.PI * 2 * step / numCircles;
			
			graphics.clear();
			for (var i:int = 0; i < numCircles; i++)
			{
				var norm:Number = 1 - i / (numCircles - 1);
				var color:Number = StandardLib.interpolateColor(norm, colorStart, colorEnd);
				var alpha:Number = StandardLib.scale(norm, 0, 1, alphaStart, alphaEnd)
				graphics.beginFill(color, alpha);
				graphics.drawCircle(cx + Math.cos(angle) * radius, cy + Math.sin(angle) * radius, radius * circleRatio);
				graphics.endFill();
				angle += Math.PI * 2 / numCircles;
			}
		}
	}
}
