(:
Copyright (c) 2015, Oracle and/or its affiliates. All rights reserved.
:)
import module namespace soaplib = "http://xmlns.oracle.com/comms/ordermanagement/oss/soap/library" at "http://oracle.communications.ordermanagement.oss.resources/xquery/library/soap/SoapLibrary.xqy";

declare namespace soapenv="http://schemas.xmlsoap.org/soap/envelope/";
declare namespace ent="http://xmlns.oracle.com/communications/inventory/webservice/enterpriseFeasibility";
declare namespace ws="http://xmlns.oracle.com/communications/ordermanagement";
declare namespace wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd";
declare namespace saxon="http://saxon.sf.net/";
declare namespace xsl="http://www.w3.org/1999/XSL/Transform";
declare namespace oms="urn:com:metasolv:oms:xmlapi:1";
declare namespace corecom="http://xmlns.oracle.com/EnterpriseObjects/Core/Common/V2" ;

(: only require to be declared when editing with Oxygen :)
declare namespace automator = "java:oracle.communications.ordermanagement.automation.plugin.ScriptSenderContextInvocation";
(: only require to be declared when editing with Oxygen :)
declare namespace context = "java:com.mslv.oms.automation.TaskContext";
(: only require to be declared when editing with Oxygen :)

declare namespace outboundMessage = "java:javax.jms.TextMessage";
declare namespace log = "java:org.apache.commons.logging.Log";

declare namespace ebo = "http://xmlns.oracle.com/EnterpriseObjects/Core/EBO/TechnicalOrder/V1";
declare namespace techord = "http://xmlns.oracle.com/EnterpriseObjects/Core/EBO/TechnicalOrder/V1";

declare option saxon:output "method=xml";
declare option saxon:output "saxon:indent-spaces=4";

declare variable $automator external;
declare variable $context external;
declare variable $outboundMessage external;
declare variable $log external;
declare variable $taskName := context:getTaskMnemonic( $context );

declare variable $uimmap := "uim";
declare variable $uimkey := "uim";

(: Create the Request element.  :)   
declare function local:addPADIRequest(
     $orderData as element()*) as element()* { 
   
   let $subId   := fn:normalize-space($orderData/*:_root/*:EBOProvisioningOrder/*:ProcessProvisioningOrderEBM/*:DataArea/*:ProcessProvisioningOrder/*:CustomerPartyReference/*:CustomerPartyAccountIdentification/*:ID/text())
   let $subName := fn:normalize-space($orderData/oms:_root/oms:ControlData/oms:OrderItem[1]/*:Subscriber/*:SubscriberName/text())

return(
                <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ent="http://xmlns.oracle.com/communications/inventory/webservice/enterpriseFeasibility">
                    <soapenv:Header/>
                   <soapenv:Body>
                      <ent:createSubscriberRequest>
                         <id>{$subId}</id>
                         <name>{$subName}</name>
                      </ent:createSubscriberRequest>
                   </soapenv:Body>           
                </soapenv:Envelope>
)
};

let $taskData                   := fn:root(.)/oms:GetOrder.Response
let $osmOrderId                 := $taskData/oms:OrderID/text()
let $AccessDeviceRequest        := local:addPADIRequest($taskData)
let $revisionNumber             := $taskData/oms:_root/oms:CustomerHeaders/oms:Identification/oms:Revision/oms:Number/text()
let $RequestPretty              := saxon:serialize($AccessDeviceRequest, <xsl:output method='xml' omit-xml-declaration='yes' indent='yes' saxon:indent-spaces='4'/>)
let $orderDataPretty            := saxon:serialize($taskData, <xsl:output method='xml' omit-xml-declaration='yes' indent='yes' saxon:indent-spaces='4'/>)
let $name                       := $taskData/*:_root/*:ControlData/*:Functions/*:TSQFunction/*:orderItem[1]/*:orderItemRef/*:ServiceDomain/text()
let $addedItem                  := $taskData/*:_root/*:ControlData/*:Functions/*:TSQFunction/*:orderItem/*:orderItemRef[*:ServiceActionCode/text()='Add']

(: Added condition to check type of Service and Action code
Create Subscriber needs to be called only for L3, Wifi, Metro with Action code Add :)
return (
        log:info($log, concat("Service Type : ",$name)),
        if ((fn:contains($name,'Service_CFS') 
            or fn:contains($name,'Wifi_CFS')
            or fn:contains($name,'MetroEthernet_CFS')) and fn:exists($addedItem)) 
        then
        (
            outboundMessage:setStringProperty( $outboundMessage, "URI", "/EnterpriseFeasibilityUim/EnterpriseFeasibilityUimJMS"),
            outboundMessage:setStringProperty( $outboundMessage, "_wls_mimehdrContent_Type", "text/xml; charset=UTF-8"),
            outboundMessage:setJMSCorrelationID($outboundMessage, fn:concat($taskName,"_",$osmOrderId,"_",$revisionNumber)),
            log:info($log, concat("Request=",$RequestPretty)),
            $RequestPretty
        )
        else 
        (
            context:completeTaskOnExit($context,"Complete")
        )
)