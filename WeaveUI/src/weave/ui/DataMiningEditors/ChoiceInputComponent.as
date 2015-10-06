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
	 * UI component used for displaying options for data mining algorithm inputs
	 * Consists of a label and a combobox
	 * @spurushe
	 */
	import mx.controls.ComboBox;
	
	import weave.ui.Indent;

	public class ChoiceInputComponent extends Indent
	{
		public var choiceBox:ComboBox = new ComboBox();
		public var identifier:String = new String();
		
		public function ChoiceInputComponent(_identifier:String = null, _objects:Array = null)
		{
			this.identifier = _identifier;
			choiceBox.dataProvider = _objects;
		}
		
		override protected function createChildren():void
		{
			super.createChildren();
			this.addChild(choiceBox);
			
		}
	}
}