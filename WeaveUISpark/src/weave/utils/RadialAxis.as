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

package weave.utils
{
	import flash.display.BitmapData;
	import flash.display.Graphics;
	import flash.geom.Point;
	import flash.text.TextFormatAlign;
	
	import weave.Weave;
	import weave.api.primitives.IBounds2D;
	import weave.compiler.StandardLib;

	/**
	 * A class for dealing with the radial axis problem.   
	 * @author curran
	 */
	public class RadialAxis
	{
		/**
		 * The minimum value of the column.
		 */
		private var min:Number;
		/**
		 * The maximum value of the column.
		 */
 		private var max:Number;
 		/**
		 * The approximate number of tick marks.
		 */
		private var n:Number;
		
		/**
		 * The length of major tick marks
		 */
		//TODO make this a sessioned variable
		//TODO add UI for editing this
		private var majorTickMarkLength:Number = 0.05;

		/**
		 * The length of minor tick marks
		 */
		//TODO make this a sessioned variable
		//TODO add UI for editing this
		private var minorTickMarkLength:Number = 0.2;
		
		private var isInitialized:Boolean = false;
		
		private var majorInterval:Number,firstMajorTickMarkValue:Number;
		
		//reusable object, used for projection to screen coordinates
		private const p:Point = new Point();
		
		// reusable object containing text style information for tick mark labels
		private const tickMarkLabel:BitmapText = new BitmapText();
		
		public function RadialAxis(){
			
			//set the font and style for the tick mark label text
			tickMarkLabel.horizontalAlign = BitmapText.HORIZONTAL_ALIGN_CENTER;
			tickMarkLabel.textFormat.align = TextFormatAlign.CENTER;
			tickMarkLabel.verticalAlign = BitmapText.VERTICAL_ALIGN_MIDDLE;
			tickMarkLabel.angle = 0;
			tickMarkLabel.width = 80;
		}
		
		/**
		 * Initializes the data-specific parameters:
		 * min - The minimum value of the column.
		 * max - The maximum value of the column.
		 * n - The approximate number of tick marks desired.
		 */
		public function setParams(min:Number,max:Number,n:Number):void{
			this.min = min;
			this.max = max;
			this.n = n;
			majorInterval = TickMarkUtils.getNiceInterval(min, max, n);
			firstMajorTickMarkValue = TickMarkUtils.getFirstTickValue(min,majorInterval);
			isInitialized = true;
		}
		
		/**
		 * Draws the radial axis.
		 * r - the radius of the axis
		 * theta - the angle offset defining the wedge size (begin angle = theta, end angle = PI - theta)
		 */
		public function draw(r:Number,theta:Number,labelsRadius:Number,dataBounds:IBounds2D, screenBounds:IBounds2D,g:Graphics,destination:BitmapData):void{
			if(isInitialized){
				var minAngle:Number = theta;
				var maxAngle:Number = Math.PI-theta;
			
				var norm:Number,angle:Number,sin:Number,cos:Number;
				
				var r1:Number = r-majorTickMarkLength/2;
				var r2:Number = r+majorTickMarkLength/2;
				
//				var value:Number = firstMajorTickMarkValue;
				for (var value:Number = firstMajorTickMarkValue; value < max; value += majorInterval) {
//				for (var i:Number = 0; value < max; i++) {
//					value = firstMajorTickMarkValue + i*majorInterval;
					norm = (value - min) / (max - min);
					angle = (1 - norm) * (maxAngle - minAngle) + minAngle;
					
					sin = Math.sin(angle);
					cos = Math.cos(angle);
					
					p.x = cos*r1;
					p.y = sin*r1;
					dataBounds.projectPointTo(p, screenBounds);
					g.moveTo(p.x,p.y);
					
					p.x = cos*r2;
					p.y = sin*r2;
					dataBounds.projectPointTo(p, screenBounds);
					g.lineTo(p.x,p.y);
					
					p.x = cos*labelsRadius;
					p.y = sin*labelsRadius;
					dataBounds.projectPointTo(p, screenBounds);
					tickMarkLabel.text = String(StandardLib.roundSignificant(value,8));
					tickMarkLabel.x = p.x;
					tickMarkLabel.y = p.y;
					LinkableTextFormat.defaultTextFormat.copyTo(tickMarkLabel.textFormat);
					tickMarkLabel.draw(destination);
					
					//a marker for testing whether text is centered properly
					//g.drawCircle(p.x,p.y,2);
					
				}
			}
		}
	}
}
