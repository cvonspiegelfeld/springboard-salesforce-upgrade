<?xml version="1.0" encoding="UTF-8"?>
<Workflow xmlns="http://soap.sforce.com/2006/04/metadata">
    <fieldUpdates>
        <fullName>Set_Goal_Type_on_Personal_Campaign</fullName>
        <description>Set&apos;s the goal type to &apos;amount raised&apos; when a personal campaign object is created.</description>
        <field>Goal_Type__c</field>
        <literalValue>Amount Raised</literalValue>
        <name>Set Goal Type on Personal Campaign</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Literal</operation>
        <protected>false</protected>
    </fieldUpdates>
    <rules>
        <fullName>Set Personal Campaign Goal Type</fullName>
        <actions>
            <name>Set_Goal_Type_on_Personal_Campaign</name>
            <type>FieldUpdate</type>
        </actions>
        <active>true</active>
        <criteriaItems>
            <field>P2P_Personal_Campaign__c.Goal_Type__c</field>
            <operation>equals</operation>
        </criteriaItems>
        <description>Set&apos;s the goal type when a personal campaign is created.</description>
        <triggerType>onCreateOnly</triggerType>
    </rules>
</Workflow>
