/**
* BigBlueButton open source conferencing system - http://www.bigbluebutton.org/
*
* Copyright (c) 2010 BigBlueButton Inc. and by respective authors (see below).
*
* This program is free software; you can redistribute it and/or modify it under the
* terms of the GNU Lesser General Public License as published by the Free Software
* Foundation; either version 2.1 of the License, or (at your option) any later
* version.
*
* BigBlueButton is distributed in the hope that it will be useful, but WITHOUT ANY
* WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
* PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details.
*
* You should have received a copy of the GNU Lesser General Public License along
* with BigBlueButton; if not, see <http://www.gnu.org/licenses/>.
* 
*/
package org.bigbluebutton.main.model.users {
	import com.asfusion.mate.events.Dispatcher;
	
	import flash.events.AsyncErrorEvent;
	import flash.events.NetStatusEvent;
	import flash.net.NetConnection;
	import flash.net.Responder;
	import flash.net.SharedObject;
	
	import org.bigbluebutton.common.LogUtil;
	import org.bigbluebutton.common.Role;
	import org.bigbluebutton.core.BBB;
	import org.bigbluebutton.core.EventConstants;
	import org.bigbluebutton.core.UsersUtil;
	import org.bigbluebutton.core.events.CoreEvent;
	import org.bigbluebutton.core.managers.ConnectionManager;
	import org.bigbluebutton.core.managers.UserManager;
	import org.bigbluebutton.main.events.BBBEvent;
	import org.bigbluebutton.main.events.LogoutEvent;
	import org.bigbluebutton.main.events.MadePresenterEvent;
	import org.bigbluebutton.main.events.ParticipantJoinEvent;
	import org.bigbluebutton.main.events.PresenterStatusEvent;
	import org.bigbluebutton.main.model.ConferenceParameters;
	import org.bigbluebutton.main.model.users.events.ConnectionFailedEvent;
	import org.bigbluebutton.main.model.users.events.RoleChangeEvent;

	public class UsersSOService {
		public static const NAME:String = "ViewersSOService";
		public static const LOGNAME:String = "[ViewersSOService]";
		
		private var _participantsSO : SharedObject;
		private static const SO_NAME : String = "participantsSO";
		private static const STATUS:String = "_STATUS";
		
    private var _connectionManager:ConnectionManager;
        
		private var _room:String;
		private var _applicationURI:String;
		
		private var dispatcher:Dispatcher;
				
		public function UsersSOService(uri:String) {			
			_applicationURI = uri;
      _connectionManager = BBB.initConnectionManager();
      _connectionManager.setUri(uri);
			dispatcher = new Dispatcher();
		}
		
		public function connect(params:ConferenceParameters):void {
			_room = params.room;
      _connectionManager.connect(params);
		}
			
		public function disconnect(onUserAction:Boolean):void {
			if (_participantsSO != null) {
        _participantsSO.close();
      }
      _connectionManager.disconnect(onUserAction);
		}
		
	    public function join(userid:String, room:String):void {
			_participantsSO = SharedObject.getRemote(SO_NAME, _applicationURI + "/" + room, false);
			_participantsSO.addEventListener(NetStatusEvent.NET_STATUS, netStatusHandler);
			_participantsSO.addEventListener(AsyncErrorEvent.ASYNC_ERROR, asyncErrorHandler);
			_participantsSO.client = this;
			_participantsSO.connect(_connectionManager.connection);
      LogUtil.debug("In UserSOService:join - Setting my userid to [" + userid + "]");
      UserManager.getInstance().getConference().setMyUserid(userid);
			queryForParticipants();					
			
		}
		
		private function queryForParticipants():void {
			var nc:NetConnection = _connectionManager.connection;
			nc.call(
				"participants.getParticipants",// Remote function name
				new Responder(
	        		// participants - On successful result
					function(result:Object):void { 
						LogUtil.debug("Successfully queried participants: " + result.count); 
					},	
					// status - On error occurred
					function(status:Object):void { 
						LogUtil.error("Error occurred:"); 
						for (var x:Object in status) { 
							LogUtil.error(x + " : " + status[x]); 
						} 
						sendConnectionFailedEvent(ConnectionFailedEvent.UNKNOWN_REASON);
					}
				)//new Responder
			); //_netConnection.call
		}
				
		public function assignPresenter(userid:String, name:String, assignedBy:String):void {
			var nc:NetConnection = _connectionManager.connection;
			nc.call("participants.assignPresenter",// Remote function name
				new Responder(
					// On successful result
					function(result:Boolean):void { 
						
						if (result) {
							LogUtil.debug("Successfully assigned presenter to: " + userid);							
						}	
					},	
					// status - On error occurred
					function(status:Object):void { 
						LogUtil.error("Error occurred:"); 
						for (var x:Object in status) { 
							LogUtil.error(x + " : " + status[x]); 
						} 
					}
				), //new Responder
				userid,
				assignedBy
			); //_netConnection.call
		}
		

		
		public function kickUser(userid:String):void{
			_participantsSO.send("kickUserCallback", userid);
		}
		
		public function kickUserCallback(userid:String):void{
			if (UserManager.getInstance().getConference().amIThisUser(userid)){
				dispatcher.dispatchEvent(new LogoutEvent(LogoutEvent.USER_LOGGED_OUT));
			}
		}
		

					
		public function raiseHand(userID:String, raise:Boolean):void {
			var nc:NetConnection = _connectionManager.connection;			
			nc.call(
				"participants.setParticipantStatus",// Remote function name
				responder,
        userID,
				"raiseHand",
				raise
			); //_netConnection.call
		}
		
		public function addStream(userID:String, streamName:String):void {
			var nc:NetConnection = _connectionManager.connection;	
			nc.call(
				"participants.setParticipantStatus",// Remote function name
				responder,
        userID,
				"hasStream",
				"true,stream=" + streamName
			); //_netConnection.call
		}
		
		public function removeStream(userID:String, streamName:String):void {
			var nc:NetConnection = _connectionManager.connection;			
			nc.call(
				"participants.setParticipantStatus",// Remote function name
				responder,
        userID,
				"hasStream",
				"false,stream=" + streamName
			); //_netConnection.call
		}

		private function netStatusHandler(event:NetStatusEvent):void {
			var statusCode:String = event.info.code;
			
			switch (statusCode)  {
				case "NetConnection.Connect.Success" :
					LogUtil.debug(LOGNAME + ":Connection Success");		
					sendConnectionSuccessEvent();			
					break;
			
				case "NetConnection.Connect.Failed" :			
					LogUtil.debug(LOGNAME + ":Connection to viewers application failed");
					sendConnectionFailedEvent(ConnectionFailedEvent.CONNECTION_FAILED);
					break;
					
				case "NetConnection.Connect.Closed" :									
					LogUtil.debug(LOGNAME + ":Connection to viewers application closed");
					sendConnectionFailedEvent(ConnectionFailedEvent.CONNECTION_CLOSED);
					break;
					
				case "NetConnection.Connect.InvalidApp" :				
					LogUtil.debug(LOGNAME + ":Viewers application not found on server");
					sendConnectionFailedEvent(ConnectionFailedEvent.INVALID_APP);
					break;
					
				case "NetConnection.Connect.AppShutDown" :
					LogUtil.debug(LOGNAME + ":Viewers application has been shutdown");
					sendConnectionFailedEvent(ConnectionFailedEvent.APP_SHUTDOWN);
					break;
					
				case "NetConnection.Connect.Rejected" :
					LogUtil.debug(LOGNAME + ":No permissions to connect to the viewers application" );
					sendConnectionFailedEvent(ConnectionFailedEvent.CONNECTION_REJECTED);
					break;
					
				default :
				   LogUtil.debug(LOGNAME + ":default - " + event.info.code );
				   sendConnectionFailedEvent(ConnectionFailedEvent.UNKNOWN_REASON);
				   break;
			}
		}
			
		private function asyncErrorHandler(event:AsyncErrorEvent):void {
			LogUtil.debug(LOGNAME + "participantsSO asyncErrorHandler " + event.error);
			sendConnectionFailedEvent(ConnectionFailedEvent.ASYNC_ERROR);
		}
		
		public function get connection():NetConnection {
			return _connectionManager.connection;
		}
		
		private function sendConnectionFailedEvent(reason:String):void{
			/*var e:ConnectionFailedEvent = new ConnectionFailedEvent(ConnectionFailedEvent.CONNECTION_LOST);
			e.reason = reason;
			dispatcher.dispatchEvent(e);*/
		}
		
		private function sendConnectionSuccessEvent():void{
			//TODO
		}
		
		private var responder:Responder = new Responder(
			// On successful result
			function(result:Boolean):void { 	
			},	
			// On error occurred
			function(status:Object):void { 
				LogUtil.error("Error occurred:"); 
				for (var x:Object in status) { 
					LogUtil.error(x + " : " + status[x]); 
				} 
			}
		)
	}
}