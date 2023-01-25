/* Licensed Materials - Property of IBM                                   */
/*                                                                        */
/* SAMPLE                                                                 */
/*                                                                        */
/* (c) Copyright IBM Corp. 2019 All Rights Reserved                       */
/*                                                                        */
/* US Government Users Restricted Rights - Use, duplication or disclosure */
/* restricted by GSA ADP Schedule Contract with IBM Corp                  */
/*                                                                        */

package com.ibm.cicsdev.jmx;

import java.lang.management.ManagementFactory;
import java.text.SimpleDateFormat;
import java.util.Date;

import javax.management.InstanceNotFoundException;
import javax.management.MBeanException;
import javax.management.MBeanServer;
import javax.management.MalformedObjectNameException;
import javax.management.ObjectName;
import javax.management.ReflectionException;

import com.ibm.cics.server.CCSIDErrorException;
import com.ibm.cics.server.Channel;
import com.ibm.cics.server.ChannelErrorException;
import com.ibm.cics.server.CodePageErrorException;
import com.ibm.cics.server.Container;
import com.ibm.cics.server.ContainerErrorException;
import com.ibm.cics.server.InvalidRequestException;
import com.ibm.cics.server.Task;
import com.ibm.cics.server.invocation.CICSProgram;
import com.ibm.cicsdev.jmx.datastructures.WLPData;
import com.ibm.cicsdev.jmx.datastructures.WLPResp;

public class HttpEndpointController {

	private static final int OUT_WLP_ERROR_MSG_LENGTH = 256;
	private static SimpleDateFormat dfTime = new SimpleDateFormat("MM/dd/yy HH:mm:ss:SSS");
	
	@CICSProgram("WLPCTRL")
	public static void controlLiberty() {

		MBeanServer mbs = ManagementFactory.getPlatformMBeanServer();
		Task t = Task.getTask();
		Channel channel = t.getTransactionChannel();
		String msg = null;
		int returnCode = 1; // default value, i.e. operation failed
		if (channel==null) {
			msg = "Error getting the transaction channel";
			putInContainer(returnCode, msg);
			return;
		}
		
		try {
			ObjectName mbean = new ObjectName("WebSphere:feature=kernel,name=ServerEndpointControl"); // MBean name
			if (mbs.isRegistered(mbean)) {
                
                // Get input parameters: operation and endpoint
				Container input = channel.getContainer("WLPDATA"); 
				WLPData wlpData = new WLPData(input.get()); 
				String operation = wlpData.getRuleOperation().trim().toLowerCase(); // name of MBean operation 
				String endpoint = wlpData.getRuleEndpoint().trim(); // name of HTTP endpoint
				
				String[] targets = new String[] { endpoint };
				String[] signature = new String[] { "java.lang.String" }; // signature of targets object																			
				// Invoke the MBean operation
				mbs.invoke(mbean, operation, targets, signature);
				
				// Check if operation was successful
				boolean isPaused = (boolean) mbs.invoke(mbean, "isPaused", targets, signature);
				if (operation.equals("resume") && isPaused || operation.equals("pause") && !isPaused) {
					msg = "ServerEndpointControl MBean " + operation + " on " + endpoint + " FAILED";					
				} else {
					// SUCCESS
					returnCode = 0;
					msg = "ServerEndpointControl MBean has " + operation + "d: " + endpoint;
				}
			} else {
				msg = "Error calling code ServerEndpointControl resume";
			}

		} catch (MalformedObjectNameException | InstanceNotFoundException | ReflectionException | MBeanException e) {
			msg = "Error invoking ServerEndpointControl MBean";
			e.printStackTrace();
		// if compiled with CICS V5.6 or higher change the following catch to add LengthErrorException
		// i.e. --> } catch (ContainerErrorException | LengthErrorException e) {
		} catch (ContainerErrorException e) {
			msg = "Error getting WLPDATA container from channel";
			e.printStackTrace();
		} catch (ChannelErrorException | CCSIDErrorException | CodePageErrorException | LengthErrorException e) {
			msg = "Error getting data from WLPDATA container";
			e.printStackTrace();
		} finally {
			printMsg(msg);
			putInContainer(returnCode, msg);
		}
	}

	public static String formatTime() {
		
		String time = dfTime.format(new Date());
		return time;
	}

	public static void printMsg(String msg) {

		long threadID = Thread.currentThread().getId();
		System.out.println("Thread(" + threadID + ") " + formatTime() + " " + msg);
		System.out.flush();
	}

	
	private static void putInContainer(int returnCode, String msg) {
		Task t = Task.getTask();
		Channel channel = t.getTransactionChannel();
		
		WLPResp wlpResp = new WLPResp();
		wlpResp.setWlpReturnCode(returnCode);
		if (returnCode==0) {
			wlpResp.setWlpErrorMsg("");
			wlpResp.setWlpErrorMsgLen(0);
		} else {
			int messageLength = msg.length();
			if (messageLength > OUT_WLP_ERROR_MSG_LENGTH) {
				messageLength = OUT_WLP_ERROR_MSG_LENGTH;
			}
			wlpResp.setWlpErrorMsg(msg.substring(0, messageLength));
			wlpResp.setWlpErrorMsgLen(messageLength);
		}
		
		try {
			Container output = channel.createContainer("WLPRESP");
			output.put(wlpResp.getByteBuffer());
		} catch (ContainerErrorException | ChannelErrorException | InvalidRequestException | CCSIDErrorException | CodePageErrorException e) {
			e.printStackTrace();
		}
	}
}
