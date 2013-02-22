/**
* BigBlueButton open source conferencing system - http://www.bigbluebutton.org/
* 
* Copyright (c) 2012 BigBlueButton Inc. and by respective authors (see below).
*
* This program is free software; you can redistribute it and/or modify it under the
* terms of the GNU Lesser General Public License as published by the Free Software
* Foundation; either version 3.0 of the License, or (at your option) any later
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
package org.bigbluebutton.conference.service.chat;

import java.util.Map;
import org.slf4j.Logger;
import org.bigbluebutton.conference.BigBlueButtonSession;
import org.bigbluebutton.conference.Constants;
import org.bigbluebutton.conference.IBigBlueButtonGateway;
import org.red5.logging.Red5LoggerFactory;import org.red5.server.api.Red5;

public class ChatService {
	
	private static Logger log = Red5LoggerFactory.getLogger( ChatService.class, "bigbluebutton" );
	
	private IBigBlueButtonGateway bbbGW;

	public void sendPublicChatHistory() {
		String meetingID = Red5.getConnectionLocal().getScope().getName();
		bbbGW.sendPublicChatHistory(meetingID, getMyUserId());
	}
	
	public void sendPublicMessage(Map<String, Object> msg) {
		String meetingID = Red5.getConnectionLocal().getScope().getName();
		
		ChatMessageVO chatObj = new ChatMessageVO();
		chatObj.chatType = msg.get("chatType").toString(); 
		chatObj.fromUserID = msg.get("fromUserID").toString();
		chatObj.fromUsername = msg.get("fromUsername").toString();
		chatObj.fromColor = msg.get("fromColor").toString();
		chatObj.fromTime = Double.valueOf(msg.get("fromTime").toString());   
		chatObj.fromTimezoneOffset = Long.valueOf(msg.get("fromTimezoneOffset").toString());
		chatObj.fromLang = msg.get("fromLang").toString(); 	 
		chatObj.toUserID = msg.get("toUserID").toString();
		chatObj.toUsername = msg.get("toUsername").toString();
		chatObj.message = msg.get("message").toString();
	
		bbbGW.sendPublicMessage(meetingID, chatObj);
	}
	
	public void setBigBlueButtonGateway(IBigBlueButtonGateway bbbGW) {
		this.bbbGW = bbbGW;
	}
	
	public void sendPrivateMessage(Map<String, Object> msg){
		String meetingID = Red5.getConnectionLocal().getScope().getName();
		
		ChatMessageVO chatObj = new ChatMessageVO();
		chatObj.chatType = msg.get("chatType").toString();  
		chatObj.fromUserID = msg.get("fromUserID").toString();
		chatObj.fromUsername = msg.get("fromUsername").toString();
		chatObj.fromColor = msg.get("fromColor").toString();
		chatObj.fromTime = Double.valueOf(msg.get("fromTime").toString());   
		chatObj.fromTimezoneOffset = Long.valueOf(msg.get("fromTimezoneOffset").toString()); 
		chatObj.fromLang = msg.get("fromLang").toString(); 	  
		chatObj.toUserID = msg.get("toUserID").toString();
		chatObj.toUsername = msg.get("toUsername").toString();
		chatObj.message = msg.get("message").toString();
	
		bbbGW.sendPrivateMessage(meetingID, chatObj);

	}
	
	public String getMyUserId() {
		BigBlueButtonSession bbbSession = (BigBlueButtonSession) Red5.getConnectionLocal().getAttribute(Constants.SESSION);
		assert bbbSession != null;
		return bbbSession.getInternalUserID();
	}
}
