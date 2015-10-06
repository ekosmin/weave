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
	import flash.events.MouseEvent;
	
	import mx.controls.NumericStepper;
	
	import weave.core.UIUtils;
	
	/**
	 * Bug fix: Sets focus as soon as there is a mouseDown event.
	 */
	public class CustomNumericStepper extends NumericStepper
	{
		public function CustomNumericStepper()
		{
			addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown, true);
		}
		private function onMouseDown(event:MouseEvent):void
		{
			setFocus();
		}
	}
}
