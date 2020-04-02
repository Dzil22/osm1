(:
Copyright (c) 2017, Diksha its affiliates. All rights reserved.
Developer  ::  Madhes
:)


import module namespace lib = "http://xmlns.oracle.com/comms/ordermanagement/oss/library" at "http://oracle.communications.ordermanagement.oss.resources/xquery/library/OSSLibrary.xqy";
import module namespace soaplib = "http://xmlns.oracle.com/comms/ordermanagement/oss/soap/library" at "http://oracle.communications.ordermanagement.oss.resources/xquery/library/soap/SoapLibrary.xqy";

declare namespace soapenv="http://schemas.xmlsoap.org/soap/envelope/";
declare namespace wfm="http://xmlns.oracle.com/emulator/workforcemanagement";
declare namespace ws="http://xmlns.oracle.com/communications/ordermanagement";
declare namespace wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd";
declare namespace saxon="http://saxon.sf.net/";
declare namespace xsl="http://www.w3.org/1999/XSL/Transform";
declare namespace oms="urn:com:metasolv:oms:xmlapi:1";
declare namespace corecom="http://xmlns.oracle.com/EnterpriseObjects/Core/Common/V2";
declare namespace provord="http://xmlns.oracle.com/EnterpriseObjects/Core/EBO/ProvisioningOrder/V1";

(: only require to be declared when editing with Oxygen :)
declare namespace automator = "java:oracle.communications.ordermanagement.automation.plugin.ScriptSenderContextInvocation";
(: only require to be declared when editing with Oxygen :)
declare namespace context = "java:com.mslv.oms.automation.TaskContext";
(: only require to be declared when editing with Oxygen :)
declare namespace outboundMessage = "java:javax.jms.TextMessage";
declare namespace log = "java:org.apache.commons.logging.Log";

declare option saxon:output "method=xml";
declare option saxon:output "saxon:indent-spaces=4";

declare variable $automator external;
declare variable $context external;
declare variable $outboundMessage external;
declare variable $log external;
declare variable $mineContextType := "text/xml; charset=UTF-8";
declare variable $taskname := context:getTaskMnemonic( $context );

declare variable $wfmPrefix := "wfm:";
declare variable $wfmNamespace := "http://xmlns.oracle.com/ordermanagement/workforcemanagement";

declare variable $SiteSurveyRequest := "SiteSurveyRequest";


declare function local:generateCorrelationID(
     $orderData as element()*) as xs:string { 
   let $woOSSId := fn:concat(normalize-space(data($orderData/oms:OrderID)),'_',normalize-space(data($orderData/oms:OrderHistID)))
   return $woOSSId
};


(: Creates the soap message :)
declare function local:createWFMRequest(
    $orderData as element()*) as element()* {   

        <soapenv:Envelope 
          xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
          xmlns:ws="http://xmlns.oracle.com/communications/ordermanagement"
          xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">
           {
               
               local:addBody($orderData) 
           }
         </soapenv:Envelope>  
        
};



(: Create the soapenv:Body element.  :)   
declare function local:addBody(
     $orderData as element()*) as element()* { 
   
   (: <soapenv:Body> :)
   let $elementname := fn:QName($soaplib:soapNamespace, concat($soaplib:soapPrefix, $soaplib:Body))
   let $OrderItem  := $orderData/oms:_root/*:ControlData/*:OrderItem[1]
   where (exists($orderData ))
   return
       element {$elementname } {
             local:addWfmRequestHeader($orderData),
             local:addWfmServiceAddress($OrderItem/*:ServiceAddress,$orderData),
             local:addWfmRequest($orderData)
       }
};
declare function local:selectTaskName(
     $orderData as element()*) as xs:string* { 
    let $backupCallDone   := $orderData/oms:_root/oms:WFMData/oms:SLGData/oms:SiteSurveyForBackup/text()
    let $deviceData :=if($backupCallDone='no')
                            then($orderData/oms:_root/oms:OperationData/oms:DeviceInformation[oms:Type='ActiveDevice_MAIN'])
                            else($orderData/oms:_root/oms:OperationData/oms:DeviceInformation[oms:Type='ActiveDevice_BACKUP'])    
    return(
            if(exists($deviceData/oms:DeviceInfoParam[oms:ParamName/text()='UplinkPorttoMetro']))then('PopulateMEaccess')
            else('PopulateANUplinkPort')
    )
   
   
};
(: Create the wfm:InstallRequest element.  :)   
declare function local:addWfmRequest(
     $orderData as element()* ) as element()* { 
   
    (: <wfm:InstallRequest> :)
    let $elementname := fn:QName($wfmNamespace, concat( $wfmPrefix, $SiteSurveyRequest))
    let $OrderItem:=$orderData/oms:_root/*:ControlData/*:Functions/*:TSQFunction/*:orderItem/*:orderItemRef[*:ServiceActionCode/text()!='Move-Delete']
    return 
    (
    
    let $actionCode := $OrderItem/*:ServiceActionCode
    let $SepcializedActionName:=local:selectTaskName($orderData)
    let $Sequence :='Sequence'
    let $itemElement := fn:QName($wfmNamespace, concat( $wfmPrefix, "Item"))
    let $items := fn:QName($wfmNamespace, concat( $wfmPrefix, "InstallRequest"))
    return
    (   
        element {$items} 
         {
            element {$itemElement} 
            {
                 <wfm:Name>{$SepcializedActionName}</wfm:Name> ,
                 lib:createQualifiedElement($wfmNamespace, $wfmPrefix, 'Correlation', $OrderItem/*:BaseLineId),
                 lib:createQualifiedElement($wfmNamespace, $wfmPrefix, 'Action', $actionCode), 
                 local:addWfmDynamicParam($orderData,$SepcializedActionName)
            }
         }          
     )              
            
        
    )
};

declare function local:addWfmDynamicParam($orderData as element()*,$SepcializedActionName as xs:string*)
{  
    let $serviceElement := fn:QName($wfmNamespace, concat( $wfmPrefix, "ServiceDetail"))
    let $wfmInput :=$orderData/oms:_root/oms:OperationData/oms:GeneralInfo/oms:DeviceInformation
    let $backupCallDone     := $orderData/oms:_root/oms:WFMData/oms:SLGData/oms:SiteSurveyForBackup/text()    
    let $deviceData :=if($backupCallDone='no')
                            then($orderData/oms:_root/oms:OperationData/oms:DeviceInformation[oms:Type='ActiveDevice_MAIN'])
                            else($orderData/oms:_root/oms:OperationData/oms:DeviceInformation[oms:Type='ActiveDevice_BACKUP'])    
    return(
    if($SepcializedActionName='PopulateMEaccess')
    then(
        <wfm:Attributes>
            <wfm:Attribute>                       
                <wfm:Name>MetroAccess_Name</wfm:Name>        
                <wfm:Value>{if(exists($deviceData))then($deviceData/oms:DeviceInfoParam[oms:ParamName/text()='Name']/oms:ParamValue/text())else()}</wfm:Value>
                <wfm:Action/>
             </wfm:Attribute>
             <wfm:Attribute>
                <wfm:Name>MetroAccess_IPAddress</wfm:Name>
                <wfm:Value>{if(exists($deviceData))then($deviceData/oms:DeviceInfoParam[oms:ParamName/text()='IPAddress']/oms:ParamValue/text())else()}</wfm:Value>
                <wfm:Action/>
             </wfm:Attribute>
             <wfm:Attribute>
                <wfm:Name>MetroAccess_Portname</wfm:Name>
                <wfm:Value>{if(exists($deviceData))then($deviceData/oms:DeviceInfoParam[oms:ParamName/text()='Name']/oms:ParamValue/text())else()}</wfm:Value>
                <wfm:Action/>
             </wfm:Attribute>       
     </wfm:Attributes>
     )else(
        <wfm:Attributes>
            <wfm:Attribute>                       
                <wfm:Name>AN_Manufacturer</wfm:Name>        
                <wfm:Value>{if(exists($deviceData))then($deviceData/oms:DeviceInfoParam[oms:ParamName/text()='Manufacturer']/oms:ParamValue/text())else()}</wfm:Value>
                <wfm:Action/>
             </wfm:Attribute>
             <wfm:Attribute>
                <wfm:Name>AN_Name</wfm:Name>
                <wfm:Value>{if(exists($deviceData))then($deviceData/oms:DeviceInfoParam[oms:ParamName/text()='Name']/oms:ParamValue/text())else()}</wfm:Value>
                <wfm:Action/>
             </wfm:Attribute>
             <wfm:Attribute>
                <wfm:Name>AN_IPAddress</wfm:Name>
                <wfm:Value>{if(exists($deviceData))then($deviceData/oms:DeviceInfoParam[oms:ParamName/text()='IPAddress']/oms:ParamValue/text())else()}</wfm:Value>
                <wfm:Action/>
             </wfm:Attribute>       
     </wfm:Attributes>
     )
           )
};



declare function local:addWfmServiceAddress(
     $serviceaddress as element()*,$orderData as element()) as element()* { 
   
   
   let $elementname := fn:QName($wfmNamespace, concat( $wfmPrefix, "ServiceAddress"))
   let $Building                   := $orderData/*:_root/*:EBOProvisioningOrder/*:ProcessProvisioningOrderEBM/*:DataArea/*:ProcessProvisioningOrder/*:ProvisioningOrderLine/*:ServiceAddress/*:Building                             
   let $Floor                    := $orderData/*:_root/*:EBOProvisioningOrder/*:ProcessProvisioningOrderEBM/*:DataArea/*:ProcessProvisioningOrder/*:ProvisioningOrderLine/*:ServiceAddress/*:Floor
   let $ProvinceName                   := $orderData/*:_root/*:EBOProvisioningOrder/*:ProcessProvisioningOrderEBM/*:DataArea/*:ProcessProvisioningOrder/*:ProvisioningOrderLine/*:ServiceAddress/*:ProvinceName
   let $TKMDistrict                   := $orderData/*:_root/*:EBOProvisioningOrder/*:ProcessProvisioningOrderEBM/*:DataArea/*:ProcessProvisioningOrder/*:ProvisioningOrderLine/*:ServiceAddress/*:Custom/*:TKMDistrict
   let $TKMNumber                   := $orderData/*:_root/*:EBOProvisioningOrder/*:ProcessProvisioningOrderEBM/*:DataArea/*:ProcessProvisioningOrder/*:ProvisioningOrderLine/*:ServiceAddress/*:Custom/*:TKMNumber
   
   where (exists($serviceaddress ))
   return
       element {$elementname } {
             
             lib:createQualifiedElement($wfmNamespace, $wfmPrefix, 'AddressLine1', $serviceaddress/*:AddressLine1),
             lib:createQualifiedElement($wfmNamespace, $wfmPrefix, 'AddressLine2', $serviceaddress/*:AddressLine2),
              lib:createQualifiedElement($wfmNamespace, $wfmPrefix, 'Building', $Building),
             lib:createQualifiedElement($wfmNamespace, $wfmPrefix, 'Floor', $Floor),
             lib:createQualifiedElement($wfmNamespace, $wfmPrefix, 'ProvinceName', $ProvinceName),
             lib:createQualifiedElement($wfmNamespace, $wfmPrefix, 'TKMDistrict', $TKMDistrict),
             lib:createQualifiedElement($wfmNamespace, $wfmPrefix, 'TKMNumber', $TKMNumber),
             lib:createQualifiedElement($wfmNamespace, $wfmPrefix, 'City', $serviceaddress/*:City),
             lib:createQualifiedElement($wfmNamespace, $wfmPrefix, 'State', $serviceaddress/*:State),
             lib:createQualifiedElement($wfmNamespace, $wfmPrefix, 'PostalCode', $serviceaddress/*:PostalCode),
             lib:createQualifiedElement($wfmNamespace, $wfmPrefix, 'CountryCode', $serviceaddress/*:CountryCode),
             lib:createQualifiedElement($wfmNamespace, $wfmPrefix, 'Latitude', $serviceaddress/*:Latitude),
             lib:createQualifiedElement($wfmNamespace, $wfmPrefix, 'Longitude', $serviceaddress/*:Longitude)
       }
};




(: Create the wfm:InstallRequest header :) 
declare function local:addWfmRequestHeader(
     $orderData as element()*) as element()* { 
   
    (: <wfm:InstallRequest Header> 
        let $taskData := fn:root(.)/oms:GetOrder.Response :)
        let $wfmOid :=  $orderData/oms:OrderID/text()
        let $wfmregion := $orderData/*:_root/oms:OperationData/oms:GeneralInfo[oms:ParamName/text()='REGION']/oms:ParamValue/text()
        let $wfmregnum := $wfmregion
        let $wfmSiteId := $orderData/*:_root/oms:OperationData/oms:GeneralInfo[oms:ParamName/text()='STO']/oms:ParamValue/text()
        let $EBM := $orderData/*:_root/*:EBOProvisioningOrder
        let $provOrder := $EBM/*:ProcessProvisioningOrderEBM/*:DataArea/*:ProcessProvisioningOrder 
        let $crmOrderType :=  fn:normalize-space($orderData/*:_root/*:CustomerHeaders/*:CrmOrderType/text())
        let $woRevisionNo := $orderData/*:_root/*:CustomerHeaders/*:Identification/*:Revision/*:Number/text()
        let $crmOrderId:=$orderData/oms:Reference/text()
        let $custName:=fn:normalize-space($orderData/oms:_root/*:ControlData/*:Functions/*:TSQFunction/*:orderItem[1]/*:orderItemRef/*:Subscriber/*:SubscriberName/text())
        let $woOSSId := local:generateCorrelationID($orderData)
        let $woReqTimeSub := fn:substring-before($orderData/*:RequestedDeliveryDate/text(), "IST")
        let $woReqTime  := normalize-space($woReqTimeSub)
        let $time_value := fn:substring(fn:string(fn:current-dateTime()),0,20)
        
        let $woAction := if($crmOrderType = 'ADD') then 'CREATE' 
                            else if ($crmOrderType = 'DELETE') then 'DELETE' 
                            else()
        let $name                := $orderData/*:_root/*:ControlData/*:Functions/*:TSQFunction/*:orderItem[1]/*:orderItemRef/*:ServiceDomain/text()     
        
        let $productName    :=  
              if (fn:contains($name,'L3_VPN_Service_CFS')) 
                 then
                 (
                    "VPN"
                 )
                 else if (fn:contains($name,'Wifi_CFS')) 
                 then
                 (
                       "WIFI"
                  )
                 else if (fn:contains($name,'MetroEthernet_CFS')) 
                 then
                 (
                        "METRO"
                 )
                 else()
        
        let $name           := 'SITESURVEY'
        
       
        
        return (
            element { fn:QName($wfmNamespace, concat( $wfmPrefix, "WOHeader")) } {
                if (exists($wfmOid)) then (lib:createQualifiedElementFromString($wfmNamespace, $wfmPrefix, 'WFMWOId', '')) else (),
                if (exists($wfmregion)) then (lib:createQualifiedElementFromString($wfmNamespace, $wfmPrefix, 'WFMSITEID', $wfmregnum)) else (),
                if (exists($wfmSiteId)) then (lib:createQualifiedElementFromString($wfmNamespace, $wfmPrefix, 'WORKZONE', $wfmSiteId)) else (),
                if (exists($crmOrderId)) then (lib:createQualifiedElementFromString($wfmNamespace, $wfmPrefix, 'CrmOrderId', $crmOrderId)) else (),
                if (exists($custName)) then (lib:createQualifiedElementFromString($wfmNamespace, $wfmPrefix, 'CustomerName', $custName)) else (),
                if (exists($crmOrderType)) then (lib:createQualifiedElementFromString($wfmNamespace, $wfmPrefix, 'CrmOrderType', $crmOrderType)) else (),
                if (exists($woRevisionNo)) then (lib:createQualifiedElementFromString($wfmNamespace, $wfmPrefix, 'WORevisionNo', $woRevisionNo)) else (),
                if (exists($woOSSId)) then (lib:createQualifiedElementFromString($wfmNamespace, $wfmPrefix, 'WOOSSId', $woOSSId)) else (),
                if (exists($woReqTime)) then (lib:createQualifiedElementFromString($wfmNamespace, $wfmPrefix, 'WOReqTime', $time_value)) else (),
                if (exists($woAction)) then (lib:createQualifiedElementFromString($wfmNamespace, $wfmPrefix, 'WOAction', $woAction)) else (),
                lib:createQualifiedElementFromString($wfmNamespace, $wfmPrefix, 'WOStatus', 'STARTWORK'),
                lib:createQualifiedElementFromString($wfmNamespace, $wfmPrefix, 'ProductType', 'ENTERPRISE'),
                lib:createQualifiedElementFromString($wfmNamespace, $wfmPrefix, 'ProductName', $productName ),
                <wfm:Attributes xmlns:wfm="http://xmlns.oracle.com/emulator/workforcemanagement">
                    <wfm:Attribute>
                        <wfm:Name>Bandwidth</wfm:Name>
                        <wfm:Value></wfm:Value>
                        <wfm:Action/>
                    </wfm:Attribute>
                </wfm:Attributes>,
                <wfm:Attributes xmlns:wfm="http://xmlns.oracle.com/emulator/workforcemanagement">
                    <wfm:Attribute>
                        <wfm:Name>BandwidthGlobal</wfm:Name>
                        <wfm:Value></wfm:Value>
                        <wfm:Action/>
                    </wfm:Attribute>
                </wfm:Attributes>,
                <wfm:Attributes xmlns:wfm="http://xmlns.oracle.com/emulator/workforcemanagement">
                    <wfm:Attribute>
                        <wfm:Name>ConnectionType</wfm:Name>
                        <wfm:Value></wfm:Value>
                        <wfm:Action/>
                    </wfm:Attribute>
                </wfm:Attributes>,
                <wfm:Attributes xmlns:wfm="http://xmlns.oracle.com/emulator/workforcemanagement">
                    <wfm:Attribute>
                        <wfm:Name>Package_Name</wfm:Name>
                        <wfm:Value></wfm:Value>
                        <wfm:Action/>
                    </wfm:Attribute>
                </wfm:Attributes>               
                
            }  
            
        )
};


let $taskData           := fn:root(.)//oms:GetOrder.Response

let $osmOrderId         := $taskData/oms:OrderID/text()
let $WFMSTPCallrequest         := local:createWFMRequest( $taskData )

let $RequestPretty      := saxon:serialize($WFMSTPCallrequest, <xsl:output method='xml' omit-xml-declaration='yes' indent='yes' saxon:indent-spaces='4'/>)

let $orderDataPretty    := saxon:serialize($taskData, <xsl:output method='xml' omit-xml-declaration='yes' indent='yes' saxon:indent-spaces='4'/>)

let $componentKey       := $taskData/oms:_root/oms:ControlData/oms:Functions/*[local-name()='TSQFunction']/oms:componentKey/text()

let $id_value           := fn:concat(normalize-space(data($taskData/oms:OrderID)),'_',normalize-space(data($taskData/oms:OrderHistID)))
                        
return (

    outboundMessage:setJMSCorrelationID($outboundMessage, $id_value),
    log:debug($log, concat("Task=", $taskname)),
    log:info($log, $orderDataPretty),
    log:info($log, $RequestPretty),
    $WFMSTPCallrequest
    
)