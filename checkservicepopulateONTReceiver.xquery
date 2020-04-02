(:
Copyright (c) 2015, Oracle and/or its affiliates. All rights reserved.

:)

declare namespace soapenv="http://schemas.xmlsoap.org/soap/envelope/";
declare namespace ent="http://xmlns.oracle.com/communications/inventory/webservice/enterpriseFeasibility";
declare namespace saxon="http://saxon.sf.net/";
declare namespace xsl="http://www.w3.org/1999/XSL/Transform";
declare namespace oms="urn:com:metasolv:oms:xmlapi:1";
declare namespace automator = "java:oracle.communications.ordermanagement.automation.plugin.ScriptReceiverContextInvocation";
declare namespace context = "java:com.mslv.oms.automation.TaskContext";
declare namespace log = "java:org.apache.commons.logging.Log";

declare option saxon:output "method=xml";
declare option saxon:output "saxon:indent-spaces=4";

declare variable $automator external;
declare variable $context external;
declare variable $log external;



declare function local:processMessage(
             $uimResponse as element()* ) as element()*{ 
 

let $serviceId              := $uimResponse/*:serviceId/text()
let $serviceName            := $uimResponse/*:serviceName/text()
let $noOfPort               := $uimResponse/*:noOfportsAvailable/text()
    
return(

      <OrderDataUpdate xmlns="http://www.metasolv.com/OMS/OrderDataUpdate/2002/10/25">
                <UpdatedNodes>
                    <_root>
                        <UIM_Response>
                            <ServiceID>{$serviceId}</ServiceID>
                            <ServiceName>{$serviceName}</ServiceName>
                            <NoOfPortAvlbl>{$noOfPort}</NoOfPortAvlbl>
                        </UIM_Response>
                     </_root>
                </UpdatedNodes>
            </OrderDataUpdate>

)
}  ;

declare function local:processFailure(
                    $uimResponse as element()* )as element()*{

let $errorCode          := $uimResponse/*:statusCode/text()
let $errorDescription   := $uimResponse/*:statusMessage/text()

return(

      <OrderDataUpdate xmlns="http://www.metasolv.com/OMS/OrderDataUpdate/2002/10/25">
                <UpdatedNodes>
                    <_root>
                      <FaultData>
                        <FaultMessage>
                            <Code>{$errorCode}</Code>
                            <Description>{$errorDescription}</Description>
                         </FaultMessage>   
                      </FaultData>
                    </_root>
                </UpdatedNodes>
            </OrderDataUpdate>

)

};




let $response               := fn:root(.)
let $uimResponse            := $response/*:Envelope/*:Body/*:checkServicePopulateONTResponse
let $orderUpdate            := local:processMessage($uimResponse)

let $orderFailureUpdate     := local:processFailure($uimResponse)

let $statusCode             := $uimResponse/*:statusCode/text()
let $serviceId              := $uimResponse/*:ServiceID/text()
let $noOfPort               := $uimResponse/*:noOfportsAvailable/text()

let $orderUpdatePretty      := saxon:serialize($orderUpdate, <xsl:output method='xml' omit-xml-declaration='yes' indent='yes' saxon:indent-spaces='4'/>)
let $orderFailureUpdatePretty := saxon:serialize($orderFailureUpdate, <xsl:output method='xml' omit-xml-declaration='yes' indent='yes' saxon:indent-spaces='4'/>)
return (

    log:info($log ,  concat("Failure-----", $orderFailureUpdatePretty)),
    (: if (fn:contains($statusCode, '9001'))
     then (       
          log:info($log, $orderUpdatePretty),
          automator:setUpdateOrder($automator,"true"),
          $orderUpdate ,
          context:completeTaskOnExit($context, "success")  
        ) :)
     if (fn:exists($serviceId) and fn:exists($noOfPort))
    then (       
          log:info($log, $orderUpdatePretty),
          automator:setUpdateOrder($automator,"true"),
          $orderUpdate ,
          context:completeTaskOnExit($context, "success")  
        )  
        else (
             log:info($log, concat("Fail-----", $orderFailureUpdatePretty)),
             $orderFailureUpdate,
             context:completeTaskOnExit($context, "failure")
        )
       
     )

