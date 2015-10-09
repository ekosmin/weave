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
	import com.adobe.devnet.events.PodStateChangeEvent;
	import com.adobe.devnet.managers.PodLayoutManager;
	import com.adobe.devnet.view.Pod;
	
	import flash.events.Event;
	import flash.utils.Dictionary;
	
	import mx.core.IVisualElement;
	
	import spark.components.Group;
	
	import weave.api.core.IDisposableObject;
	import weave.api.core.ILinkableObject;
	import weave.api.getCallbackCollection;
	import weave.api.linkBindableProperty;
	import weave.api.newLinkableChild;
	import weave.api.registerLinkableChild;
	import weave.api.ui.ILinkableLayoutManager;
	import weave.core.LinkableBoolean;
	import weave.core.LinkableNumber;
	
	/**
	 * @author sanbalag
	 */
	public class WeavePodLayoutManager extends Group implements ILinkableLayoutManager, IDisposableObject
	{
		public function WeavePodLayoutManager()
		{
			percentWidth = 100;
			percentHeight = 100;
			manager.container = this;
			linkBindableProperty(scale, this, 'scaleX');
			linkBindableProperty(scale, this, 'scaleY');
			manager.addEventListener(PodStateChangeEvent.CLOSE, handlePodClose);
		}
		
		//public const allowClose:LinkableBoolean = registerLinkableChild(this, new LinkableBoolean(true));
		public const scale:LinkableNumber = registerLinkableChild(this, new LinkableNumber(1));
		
		private var _idToPod:Object = {}; // String -> Pod
		private var _idToComponent:Object = {}; // String -> IVisualElement
		private var _componentToId:Dictionary = new Dictionary(true); // IVisualElement -> String
		
		public const manager:PodLayoutManager = new PodLayoutManager();
		
		private function handlePodClose(event:Event):void
		{
			removeComponent(manager.closedPod.id);
		}
		
		/**
		 * Adds a component to the layout.
		 * @param id A unique identifier for the component.
		 * @param component The component to add to the layout.
		 */		
		public function addComponent(id:String, component:IVisualElement):void
		{
			var existingComponent:IVisualElement = _idToComponent[id] as IVisualElement;
			if (existingComponent != component)
			{
				if (existingComponent)
					removeComponent(id);
				
				weaveTrace('addComponent ' + id);
				var pod:Pod = new Pod();
				pod.id = id;
				
				_idToComponent[id] = component;
				_componentToId[component] = id;
				_idToPod[id] = pod;
				
				pod.addElement(component);
				pod.title = id;
				
				var busyIndicator:IVisualElement = new BusyIndicator(component as ILinkableObject) as IVisualElement;
				pod.addElement(busyIndicator);
				busyIndicator.includeInLayout = false;
				busyIndicator.x = 0;
				busyIndicator.y = 0;
				
				manager.addItem(pod, false);
				callLater(manager.updateLayout);
					
				getCallbackCollection(this).triggerCallbacks();
			}
		}
		
		/**
		 * Removes a component from the layout.
		 * @param id The id of the component to remove.
		 */
		public function removeComponent(id:String):void
		{
			var component:IVisualElement = _idToComponent[id] as IVisualElement;
			if (component)
			{
				weaveTrace('removeComponent ' + id);
				var pod:Pod = _idToPod[id];
				
				delete _idToPod[id];
				delete _idToComponent[id];
				delete _componentToId[component];
				
				if (pod.parent)
					pod.close();
					
				getCallbackCollection(this).triggerCallbacks();
			}
		}
		
		/**
		 * Reorders the components. 
		 * @param orderedIds An ordered list of ids.
		 */
		public function setComponentOrder(orderedIds:Array):void
		{
			getCallbackCollection(this).delayCallbacks();
			
			for (var index:int = 0; index < orderedIds.length; index++)
			{
				var id:String = orderedIds[index] as String;
				var component:IVisualElement = _idToComponent[id] as IVisualElement;
				if (component)
				{
					if (component.parent == this)
						this.setElementIndex(component, index);
					getCallbackCollection(this).triggerCallbacks();
				}
			}
			
			getCallbackCollection(this).resumeCallbacks();
		}
		
		/**
		 * This is an ordered list of ids in the layout.
		 */		
		public function getComponentOrder():Array
		{
			var result:Array = [];
			for (var index:int = 0; index < numElements; index++)
			{
				var component:IVisualElement = getElementAt(index);
				var id:String = _componentToId[component];
				if (id)
					result.push(id);
			}
			return result;
		}
		
		/**
		 * This function can be used to check if a component still exists in the layout.
		 */		
		public function hasComponent(id:String):Boolean
		{
			var component:IVisualElement = _idToComponent[id] as IVisualElement;
			return component != null;
		}
		
		/**
		 * This is called when the object is disposed.
		 */
		public function dispose():void
		{
			getCallbackCollection(this).delayCallbacks();
			
			for each (var id:String in getComponentOrder())
			removeComponent(id);
			
			getCallbackCollection(this).resumeCallbacks();
		}
	}
}