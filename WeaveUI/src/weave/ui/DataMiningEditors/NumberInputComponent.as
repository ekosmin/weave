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

package weave.ui.DataMiningEditors
{
	/**
	 * UI component used for collecting numerical data mining algorithm inputs
	 * Consists of a label and a textinput
	 * @spurushe
	 */
	import weave.ui.Indent;
	import weave.ui.TextInputWithPrompt;

	public class NumberInputComponent extends Indent
	{
		public var numberInput:TextInputWithPrompt = new TextInputWithPrompt();
		public var identifier:String = new String();
		
		public function NumberInputComponent(_identifier:String = null, _inputPrompt:String = null)
		{
			this.identifier = _identifier;
			numberInput.prompt = _inputPrompt;
		}
		
		
		override protected function createChildren():void
		{
			super.createChildren();
			this.addChild(numberInput);
			
		}
	}
}