/**
*Copyright 2019 Lawrence Newcombe
*
*Permission is hereby granted, free of charge, to any person obtaining a copy 
*of this software and associated documentation files (the "Software"), to deal 
*in the Software without restriction, including without limitation the rights 
*to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies 
*of the Software, and to permit persons to whom the Software is furnished to do 
*so, subject to the following conditions:
*
*The above copyright notice and this permission notice shall be included in all 
*copies or substantial portions of the Software.
*
*THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
*IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS 
*FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR 
*COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER 
*IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN 
*CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
**/

@IsTest
public with sharing class FormulaShareTriggerHelperTest {

    public static void setMocks() {
        FormulaShareService mockFSService = (FormulaShareService) FormulaShareMockUtil.createMock(FormulaShareService.class);
        FormulaShareService.mock = mockFSService;
    }


    @IsTest
    public static void testShareRecordsOnInsert() {
        setMocks();
        Schema.SObjectType fsLogType = FormulaShare_Log__c.SObjectType;

        FormulaShareTriggerHelper helper = new FormulaShareTriggerHelper();

        FormulaShare_Log__c log1 = new FormulaShare_Log__c();
        Group grp = [SELECT Id FROM Group WHERE DeveloperName = 'AllInternalUsers'][0];
        log1.Type_In_Scope__c = grp.Id;      // Should trigger sharing rule
        insert log1;

        FormulaShare_Log__c log2 = new FormulaShare_Log__c();
        log2.Number_Of_Rules__c = 14;      // Should not trigger sharing rule
        insert log2;

        Map<Id,SObject> newRecords = new Map<Id,SObject>();
        newRecords.put(log1.Id, log1);
        newRecords.put(log2.Id, log2);

        helper.handleChanges(fsLogType, null, newRecords);

        // Check that class variables populated as expected
        system.assert(!helper.populatedFsServiceMap.isEmpty(), 'FormulaShareService not initialised by method call');
        system.assertEquals(1, helper.populatedFsServiceMap.size());
        system.assert(!helper.recordsWithSharingChanges.values().isEmpty(), 'Updated record not submitted for recalculation');
        system.assertEquals(1, helper.recordsWithSharingChanges.size(), 'Too many records submitted for recalculation');
        
        List<FormulaShare_Log__c> records = (List<FormulaShare_Log__c>) helper.recordsWithSharingChanges.values();
        system.assertEquals(log1.Id, records[0].Id, 'Wrong record included for recalculation');
        system.assertEquals(grp.Id, records[0].Type_In_Scope__c, 'Modified field not set as expected');
    }


    @IsTest
    public static void testShareRecordsIdentifiedOnUpdate() {
        setMocks();
        Schema.SObjectType fsLogType = FormulaShare_Log__c.SObjectType;
        Group grp = [SELECT Id FROM Group WHERE DeveloperName = 'AllInternalUsers'][0];

        FormulaShareTriggerHelper helper = new FormulaShareTriggerHelper();

        FormulaShare_Log__c log1Old = new FormulaShare_Log__c();
        log1Old.Type_In_Scope__c = grp.Id;
        insert log1Old;

        FormulaShare_Log__c log2Old = new FormulaShare_Log__c();
        log2Old.Type_In_Scope__c = grp.Id;
        insert log2Old;

        // Simulate record being modifed in a way which would trigger sharing recalculation
        FormulaShare_Log__c log1New = log1Old.clone(true, true, false, false);
        log1New.Type_In_Scope__c = 'something different';       // This should ensure that sharing field recognised as modified

        // Simulate record being modifed in a way which should be excluded from sharing recalculation
        FormulaShare_Log__c log2New = log2Old.clone(true, true, false, false);
        log2New.Number_Of_Rules__c = 14;      // Should not trigger sharing rule

        Map<Id,SObject> existingRecords = new Map<Id,SObject>();
        Map<Id,SObject> newRecords = new Map<Id,SObject>();
        existingRecords.put(log1Old.Id, log1Old);
        existingRecords.put(log2Old.Id, log2Old);
        newRecords.put(log1New.Id, log1New);
        newRecords.put(log2New.Id, log2New);

        // Call helper method
        helper.handleChanges(fsLogType, existingRecords, newRecords);

        // Check that class variables populated as expected
        system.assert(!helper.populatedFsServiceMap.isEmpty(), 'FormulaShareService not initialised by method call');
        system.assertEquals(1, helper.populatedFsServiceMap.size());
        system.assert(!helper.recordsWithSharingChanges.values().isEmpty(), 'Updated record not submitted for recalculation');
        system.assertEquals(1, helper.recordsWithSharingChanges.size(), 'Too many records submitted for recalculation');
        
        List<FormulaShare_Log__c> records = (List<FormulaShare_Log__c>) helper.recordsWithSharingChanges.values();
        system.assertEquals(log1New.Id, records[0].Id, 'Wrong record included for recalculation');
        system.assertEquals('something different', records[0].Type_In_Scope__c, 'Modified field not set as expected');

    }


    @IsTest
    public static void testGetSharesToInsert() {
        FormulaShareService mockFSService = (FormulaShareService) FormulaShareMockUtil.createMock(FormulaShareService.class);
        Schema.SObjectType fsLogType = FormulaShare_Log__c.SObjectType;
        FormulaShareTriggerHelper helper = new FormulaShareTriggerHelper();

        helper.populatedFsServiceMap.put(fsLogType, mockFSService);

        List<FormulaShare_Log__Share> sharesToInsert = (List<FormulaShare_Log__Share>) helper.getSharesToInsert();

        system.assert(!sharesToInsert.isEmpty(), 'No shares to delete returned');
        system.assertEquals(1, sharesToInsert.size());
    }


    @IsTest
    public static void testGetSharesToDelete() {
        FormulaShareService mockFSService = (FormulaShareService) FormulaShareMockUtil.createMock(FormulaShareService.class);
        Schema.SObjectType fsLogType = FormulaShare_Log__c.SObjectType;
        FormulaShareTriggerHelper helper = new FormulaShareTriggerHelper();

        helper.populatedFsServiceMap.put(fsLogType, mockFSService);

        List<FormulaShare_Log__Share> sharesToDelete = (List<FormulaShare_Log__Share>) helper.getSharesToDelete();

        system.assert(!sharesToDelete.isEmpty(), 'No shares to delete returned');
        system.assertEquals(1, sharesToDelete.size());
    }


    @IsTest
    public static void testGetDeleteFailsWhenMoreThanOneObject() {
        FormulaShareTriggerHelper helper = new FormulaShareTriggerHelper();

        FormulaShareService mockFSService = (FormulaShareService) FormulaShareMockUtil.createMock(FormulaShareService.class);
        Schema.SObjectType fsLogType = FormulaShare_Log__c.SObjectType;
        helper.populatedFsServiceMap.put(fsLogType, mockFSService);

        // Add another entry to the FS Service map
        Schema.SObjectType contactType = Contact.SObjectType;
        helper.populatedFsServiceMap.put(contactType, mockFSService);     // Add another pair to the map

        try {
            List<FormulaShare_Log__Share> sharesToDelete = (List<FormulaShare_Log__Share>) helper.getSharesToDelete();
        }

        catch(FormulaShareTriggerHelper.FormulaShareException e) {
            system.assertEquals(e.getMessage(), 'More than one object in scope - call getSharesToDelete with object name instead');
        }
    }

}
