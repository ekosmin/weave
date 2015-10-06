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
	import flash.events.FocusEvent;
	
	import mx.controls.TextInput;
	import mx.core.mx_internal;
	
	import weave.compiler.StandardLib;

	use namespace mx_internal;

	/**
	 * This is a TextInput control that allows setting a prompt such as "Enter search text"
	 * that appears faded out when the user has not entered any text.
	 * 
	 * @author adufilie
	 */
	public class TextInputWithPrompt extends TextInput
	{
		public function TextInputWithPrompt()
		{
			super();
		}
		
		public function asTextInput():TextInput { return this; }
		
		/**
		 * If this is set to true, all the text will be selected when focus is given to the TextInput.
		 */
		[Bindable] public var autoSelect:Boolean = true;
		
		protected static const PROMPT_TEXT_ALPHA:Number = 0.5; // alpha of text when prompt is shown
		protected static const DEFAULT_TEXT_ALPHA:Number = 1.0; // alpha of text when prompt is not shown
		private var _color:Number = NaN; // stores the color that was set via setStyle
		override public function setStyle(styleProp:String, newValue:*):void
		{
			if (styleProp == 'color')
			{
				_color = newValue;
				updateTextColor();
			}
			else
			{
				super.setStyle(styleProp, newValue);
			}
		}
		
		/**
		 * This function sets the textField text color and works around a bug where setting textField.alpha does nothing.
		 */		
		private function updateTextColor():void
		{
			if (!textField)
				return;
			var alpha:Number = _promptIsShown ? PROMPT_TEXT_ALPHA : DEFAULT_TEXT_ALPHA;
			if (isNaN(_color))
				_color = getStyle('color');
			super.setStyle('color', StandardLib.interpolateColor(alpha, getStyle('backgroundColor'), _color));
		}
		
		private var _toolTipSet:Boolean = false;
		private var _promptIsShown:Boolean = true; // to know if the prompt is shown or not
		private var _prompt:String = ''; // for storing the prompt text
		
		override public function set toolTip(value:String):void
		{
			_toolTipSet = true;
			super.toolTip = value;
		}
		
		/**
		 * This is the prompt that is shown when no text has been entered.
		 */
		[Bindable]
		public function get prompt():String
		{
			return _prompt;
		}
		public function set prompt(value:String):void
		{
			_prompt = value;
			if (_promptIsShown)
			{
				super.text = _prompt;
			}
			if (!_toolTipSet)
				super.toolTip = value;
		}
		
		// this metadata is apparently required for BindingUtils.bindSetter to work
		[Bindable("textChanged")]
		[CollapseWhiteSpace]
		[Inspectable(category="General", defaultValue="")]
		[NonCommittingChangeEvent("change")]
		/**
		 * This function makes sure the prompt text gets replaced with an empty String.
		 */
		override public function get text():String
		{
			if (_promptIsShown)
				return '';
			return super.text;
		}
		
		/**
		 * Setting the text causes the prompt to disappear. 
		 */
		override public function set text(value:String):void
		{
			if (value || _hasFocus)
			{
				if (_promptIsShown)
					hidePrompt(value);
				else
					super.text = value; // bypass local setter
			}
			else
			{
				showPrompt();
			}
		}
		
		/**
		 * This function shows the prompt.
		 */
		private function showPrompt():void
		{
			if (!_promptIsShown && !_hasFocus)
			{
				_promptIsShown = true;
				
				super.text = _prompt; // bypass local setter

				updateTextColor();
			}
		}
		
		/**
		 * This function hides the prompt.
		 * @param text The new text to set in place of the prompt if the prompt is currently shown.
		 */
		private function hidePrompt(newText:String = ''):void
		{
			if (_promptIsShown)
			{
				_promptIsShown = false;
				
				super.text = newText;
				
				updateTextColor();
				
				// Validate now to make sure the inner UITextField text is updated as well.
				// This fixes a bug where the prompt text would remain if a character is typed
				// immediately after clicking in the text input.
				validateNow();
			}
		}
		
		private var _hasFocus:Boolean = false;
		
		/**
		 * This function hides the prompt if it is shown, and selects all if autoSelect is true.
		 */
		override protected function focusInHandler(event:FocusEvent):void
		{
			if (!_hasFocus)
			{
				_hasFocus = true;
				hidePrompt();

				if (autoSelect)
				{
					selectionBeginIndex = 0;
					selectionEndIndex = text.length;
				}
			}
			
			super.focusInHandler(event);
		}
		
		/**
		 * This function makes the prompt reappear if the text is empty.
		 */
		override protected function focusOutHandler(event:FocusEvent):void
		{
			if (_hasFocus)
			{
				_hasFocus = false;
				if (!text)
					showPrompt();
			}
			
			super.focusOutHandler(event);
		}
		
		/**
		 * This function initializes the alpha of the text when the TextField gets created.
		 */
		override mx_internal function createTextField(childIndex:int):void
		{
			super.createTextField(childIndex);
			updateTextColor();
		}
	}
}
