//
//  DBAssistant.m
//  Database
//
//  Created by MaSong on 15/8/20.
//  Copyright (c) 2015年 MaSong. All rights reserved.
//

#import "DBAssistant.h"
#import "NSObject+DB.h"
#import "NSObject+DBCallback.h"

static const void * const kDispatchTransactionQueueSpecificKey = &kDispatchTransactionQueueSpecificKey;

@interface DBAssistant ()
@property (strong, nonatomic) FMDatabaseQueue* dbQueue;

@property (strong, nonatomic) dispatch_queue_t  transactionQueue;
@property (assign, nonatomic) BOOL inTransaction;
@property (strong, nonatomic) FMDatabase* transactionDB;

@property (strong, nonatomic) NSRecursiveLock* threadLock;
@property (strong, nonatomic) NSString *dbPath;
@property (strong, nonatomic) NSMutableArray* createdTableNames;
@end

@implementation DBAssistant

- (void)setup{
    self.threadLock = [[NSRecursiveLock alloc]init];
    self.createdTableNames = [NSMutableArray array];
}

- (DBAssistant *)init{
    if (self = [super init]) {
        [self setup];
    }
    return self;
}

- (DBAssistant *)initWithDBPath:(NSString *)filePath{
    if([filePath isEmpty]){
        return nil;
    }
    
    if (self = [super init]) {
        [self setDBPath:filePath];
    }
    
    return self;
}


-(void)setDBPath:(NSString *)filePath{
    if(self.dbQueue && [self.dbPath isEqualToString:filePath]){
        return;
    }
    
    //创建数据库目录
    NSRange lastComponent = [filePath rangeOfString:@"/" options:NSBackwardsSearch];
    if(lastComponent.length > 0){
        
        NSString* dirPath = [filePath substringToIndex:lastComponent.location];
        BOOL isDir = NO;
        BOOL isCreated = [[NSFileManager defaultManager] fileExistsAtPath:dirPath isDirectory:&isDir];
        if ( isCreated == NO || isDir == NO ){
            NSError* error = nil;
            BOOL success = [[NSFileManager defaultManager] createDirectoryAtPath:dirPath withIntermediateDirectories:YES attributes:nil error:&error];
            if(success == NO){
                NSLog(@"create dir error: %@",error.debugDescription);
            }
        }
    }
    [self.threadLock lock];
    self.dbPath = filePath;
    [self.dbQueue close];
    self.dbQueue = [FMDatabaseQueue databaseQueueWithPath:filePath];
    
#ifdef DEBUG
    [_dbQueue inDatabase:^(FMDatabase *db) {
        db.logsErrors = YES;
    }];
#endif
    
    [self.threadLock unlock];
}


- (void)beginTransaction{
    self.inTransaction = YES;

    if (!_transactionQueue) {
        _transactionQueue = dispatch_queue_create([[NSString stringWithFormat:@"transactionQueue.%@", self] UTF8String], NULL);
        dispatch_queue_set_specific(_transactionQueue, kDispatchTransactionQueueSpecificKey, (__bridge void *)self, NULL);
    }
    if (!_transactionDB) {
        _transactionDB = [FMDatabase createDatabase:self.dbPath];
    }
    BOOL success = [_transactionDB open];
    if (!success) {
        NSLog(@"FMDatabaseQueue could not open database at path %@", self.dbPath);
    }
    if (!_transactionDB.inTransaction) {
        [_transactionDB beginTransaction];
    }
}

- (void)commit{
    if (self.inTransaction) {
        [_transactionDB commit];
        [_transactionDB close];
    }
    self.inTransaction = NO;
}

- (void)rollback{
    if (self.inTransaction) {
        [_transactionDB rollback];
        [_transactionDB close];
    }
    self.inTransaction = NO;
}

-(void)executeDB:(void (^)(FMDatabase *db))block{
    
    if (block) {
        [_threadLock lock];
        if (_inTransaction) {
            dispatch_sync(_transactionQueue, ^() {
                block(_transactionDB);
            });
        } else {
            [_dbQueue inDatabase:^(FMDatabase *db) {
                block(db);
            }];
        }
        [_threadLock unlock];
    }
}

-(BOOL)executeUpdate:(NSString *)updateSql withArguments:(NSArray *)args
{
    __block BOOL execute = NO;
    [self executeDB:^(FMDatabase *db) {
        if(args.count > 0){
            execute = [db executeUpdate:updateSql withArgumentsInArray:args];
        } else {
            execute = [db executeUpdate:updateSql];
        }
    }];
    return execute;
}


//convert db value to objc value
- (NSMutableArray *)progressResultSet:(FMResultSet *)set forTable:(NSString*)tableName targetClass:(Class)targetClass {
    
    if (set == nil) {
        return nil;
    }
    
    NSString *table_name = tableNameForClass(tableName, targetClass);
    if (table_name == nil) {
        return nil;
    }
    
    NSMutableArray* result = [NSMutableArray arrayWithCapacity:0];
    
    ModelToTableMapping* mapping = [targetClass modelToTableMapping];
    int columnCount = [set columnCount];
    if (columnCount == 0) {
        return nil;
    }
    
    while ([set next]) {
        
        NSObject* model = [[targetClass alloc]init];
        
        for (int i = 0; i < columnCount; i++) {
            
            NSString* columnName = [set columnNameForIndex:i];
            PropertyToColumnMapping* property = [mapping propertyToColumnMappingForColumnName:columnName];
            
            if(property == nil) {
                continue;
            }
            
            if(property.propertyName.length) {
                NSString* dbString = [set stringForColumnIndex:i];
                
                if (!dbString) {
                    NSData* sqlData = [set dataForColumnIndex:i];
                    dbString = [[NSString alloc] initWithData:sqlData encoding:NSUTF8StringEncoding];
                }
                
                id propertyValue = nil;
                NSString *singleAutoPK = singleAutoIncrementPrimaryKeyForClass(targetClass);
                
                if ([property.propertyName isEqualToString:singleAutoPK]) {
                    
                    propertyValue = [[NSNumber alloc]initWithInteger:[dbString integerValue]];
                } else {
                    propertyValue = [targetClass modelValueFromDBValue:dbString withPropertyToColumnMapping:property];
                }
                
                if (propertyValue) {
                    [model setValue:propertyValue forKey:property.propertyName];
                }
            }
        }
        model.table_name = table_name;
        [result addObject:model];
    }
    return result;
}

#pragma mark - drop
- (void)dropAllTables{
    [self executeDB:^(FMDatabase *db) {
        NSArray *allTableNames = [db allTableNames];
        for (NSString* tableName in allTableNames) {
            [db dropTable:tableName];
        }
    }];
}

- (BOOL)dropTableForClass:(Class)targetClass{
    NSString* tableName = [targetClass tableName];
    if ([tableName isEmpty]) {
        return NO;
    }
    
    __block BOOL success = NO;
    [self executeDB:^(FMDatabase *db) {
        success = [db dropTable:tableName];
    }];
    return success;
}


#pragma mark - create
-(void)checkHasNewColumnsInTable:(NSString *)tableName forClass:(Class)targetClass{
    
    NSString *table_name = tableNameForClass(tableName, targetClass);
    if (table_name == nil) {
        NSLog(@"ERROR! table_name is nil");
        return;
    }
    
    [self executeDB:^(FMDatabase *db){
        
        ModelToTableMapping* mapping = [targetClass modelToTableMapping];
        
        NSString* query = [NSString stringWithFormat:@"select * from %@ limit 0",table_name];
        FMResultSet* set = [db executeQuery:query];
        NSArray *currentColumns = set.columnNameToIndexMap.allKeys;
        currentColumns = [currentColumns valueForKey:@"lowercaseString"];
        [set close];
        
        
        for (int i = 0; i < mapping.count; i++){
            
            PropertyToColumnMapping* property =  [mapping propertyToColumnMappingAtIndex:i];
            
            NSString *lowercaseColumnName = property.sqlColumnName.lowercaseString;
            if ([lowercaseColumnName isEqualToString:DBRowId]) {
                continue;
            }
            
            
            if (![currentColumns containsObject:lowercaseColumnName]) {
                
                NSMutableString *addColumnParam = [NSMutableString stringWithFormat:@"%@ %@",property.sqlColumnName,property.sqlColumnType];
                
                
                if([property.sqlColumnType isEqualToString:DBTypeText] && property.length > 0){
                    [addColumnParam appendFormat:@"(%lu)",(unsigned long)property.length];
                }
                
                if(property.notNull){
                    [addColumnParam appendFormat:@" %@",DBAttributeNotNull];
                }
                
                if(property.check){
                    [addColumnParam appendFormat:@" %@(%@)",DBAttributeCheck,property.check];
                }
                
                if(property.defaultValue){
                    [addColumnParam appendFormat:@" %@ %@",DBAttributeDefault,property.defaultValue];
                }
                
                NSString* addColumnSQL = [NSString stringWithFormat:@"alter table %@ add column %@",table_name,addColumnParam];
                
                NSString* updateSQL = [NSString stringWithFormat:@"update %@ set %@=%@",table_name,property.sqlColumnName,[property.sqlColumnType isEqualToString:DBTypeText]? @"''" : @"0"];
                
                if([db executeUpdate:addColumnSQL]) {
                    [db executeUpdate:updateSQL];
                }
            }
        }
    }];
    
}

-(BOOL)createTableForClass:(Class)targetClass{
    return [self createTable:[targetClass tableName] forClass:targetClass];
}

-(BOOL)createTable:(NSString*)tableName forClass:(Class)targetClass  {
    
    NSString *table_name = tableNameForClass(tableName, targetClass);
    if (table_name == nil) {
        return NO;
    }
    
    __block BOOL isCreated = NO;
    [self executeDB:^(FMDatabase *db){
        isCreated = [db tableExists:table_name];
    }];
    
    
    if(isCreated){
        if([_createdTableNames containsObject:table_name] == NO){
            [_createdTableNames addObject:table_name];
        }
        
        [self checkHasNewColumnsInTable:table_name forClass:targetClass];
        return YES;
    }
    
    ModelToTableMapping * mapping = [targetClass modelToTableMapping];
    NSArray* primaryKeys = mapping.primaryKeys;
    NSString *singleAutoIncPK = singleAutoIncrementPrimaryKeyForClass(targetClass);
    
    NSMutableString* table_pars = [NSMutableString string];
    for (int i = 0; i < mapping.count; i++){
        
        if(i > 0){
            [table_pars appendString:@","];
        }
        
        PropertyToColumnMapping* property =  [mapping propertyToColumnMappingAtIndex:i];
        
        NSString* columnType = property.sqlColumnType;
        
        [table_pars appendFormat:@"%@ %@",property.sqlColumnName,columnType];
        
        if([property.sqlColumnType isEqualToString:DBTypeText] && property.length > 0){
            [table_pars appendFormat:@"(%lu)",(unsigned long)property.length];
        }
        
        if(property.notNull){
            [table_pars appendFormat:@" %@",DBAttributeNotNull];
        }
        
        if(property.unique){
            [table_pars appendFormat:@" %@",DBAttributeUnique];
        }
        
        if(property.check){
            [table_pars appendFormat:@" %@(%@)",DBAttributeCheck,property.check];
        }
        
        
        if(property.defaultValue){
            [table_pars appendFormat:@" %@ %@",DBAttributeDefault,property.defaultValue];
        }
        
        if(singleAutoIncPK && ([property.propertyName isEqualToString:singleAutoIncPK]|| [property.sqlColumnName isEqualToString:singleAutoIncPK])){
            [table_pars appendString:@" primary key autoincrement"];
        }
    }
    
    NSMutableString* pksb = [NSMutableString string];
    
    //UnionPrimaryKey
    if(!singleAutoIncPK && primaryKeys.count){
        NSMutableString *pkString = [NSMutableString string];
        for (int i = 0; i < primaryKeys.count; i++) {
            NSString* pk = [primaryKeys objectAtIndex:i];
            
            PropertyToColumnMapping* property = [mapping propertyToColumnMappingForPropertyName:pk];
            if (![property.propertyName isEqualToString:property.sqlColumnName]) {
                pk = property.sqlColumnName;
            }
            
            if(pkString.length > 0){
                [pkString appendString:@","];
            }
            
            [pkString appendString:pk];
        }
        if(pkString.length > 0) {
            [pkString insertString:@",primary key(" atIndex:0];
            [pkString appendString:@")"];
        }
    }
    
    NSString* createTableSQL = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@(%@%@)",tableName,table_pars,pksb];
    
    
    [self executeDB:^(FMDatabase *db){
        isCreated = [db executeUpdate:createTableSQL];
    }];
    
    if(isCreated){
        [_createdTableNames addObject:table_name];
    }
    
    return isCreated;
}

#pragma mark - find
- (id)firstModelFromTable:(NSString *)tableName where:(NSObject *)where forClass:(Class)targetClass{
    return [self firstModelFromTable:tableName where:where orderBy:nil forClass:targetClass];
}

- (id)firstModelFromTable:(NSString *)tableName where:(NSObject *)where orderBy:(NSString*)orderBy forClass:(Class)targetClass{
    NSArray *res = [self selectModelsFromTable:tableName where:where groupBy:nil orderBy:orderBy  limit:1 offset:0 forClass:targetClass];
    
    if (res.count) {
        return res[0];
    }
    return nil;
}

- (NSInteger)rowCountOfTableName:(NSString*)tableName where:(id)where forClass:(Class)targetClass{
    
    NSMutableString* rowCountSql = [NSMutableString stringWithFormat:@"select count(row_id) from %@", tableName];
    
    __block NSInteger result = 0;
    NSMutableArray *args = [NSMutableArray new];
    NSMutableString *whereQuery = [NSMutableString whereQueryForInputValue:where outputColumnValues:args];
    if ([whereQuery isSafeString]) {
        [rowCountSql appendString:whereQuery];
    }
    
    [self executeDB:^(FMDatabase *db) {
        FMResultSet* set = nil;
        if (args.count > 0) {
            set = [db executeQuery:rowCountSql withArgumentsInArray:args];
        }
        else {
            set = [db executeQuery:rowCountSql];
        }
        if (([set columnCount] > 0) && [set next]) {
            result = [[set stringForColumnIndex:0] integerValue];
        }
        [set close];
    }];
    
    return result;
}




- (NSArray *)allModelsFromTable:(NSString *)tableName forClass:(Class)targetClass{
    return [self selectModelsFromTable:tableName where:nil forClass:targetClass];
}

- (NSArray *)selectModelsFromTable:(NSString *)tableName where:(NSObject *)where forClass:(Class)targetClass{
    return [self selectModelsFromTable:tableName where:where groupBy:nil orderBy:nil  limit:0 offset:0 forClass:targetClass];
}

- (NSArray *)selectModelsFromTable:(NSString *)tableName where:(id)where groupBy:(NSString *)groupBy orderBy:(NSString*)orderBy limit:(int)limit offset:(int)offset  forClass:(Class)targetClass{
    
    NSString *table_name = tableNameForClass(tableName, targetClass);
    if (table_name == nil) {
        return nil;
    }
    
    NSMutableArray *outputWhereValues = [NSMutableArray new];
    NSMutableString *query = [NSMutableString queryStringForColumns:@"*" table:tableName where:where  groupBy:groupBy orderBy:orderBy limit:limit offset:offset outputColumnValues:outputWhereValues];
    
    
    __block NSMutableArray* result = nil;
    [self executeDB:^(FMDatabase *db){
        
        FMResultSet *rs = nil;
        if (outputWhereValues.count) {
            rs = [db executeQuery:query withArgumentsInArray:outputWhereValues];
        } else {
            rs = [db executeQuery:query ];
        }
        
        result = [self progressResultSet:rs forTable:table_name targetClass:targetClass];
        [rs close];
        
    }];
    
    
    return result;
}

- (id)lastModelFromTable:(NSString *)tableName  forClass:(Class)targetClass{
    
    NSString *table_name = tableNameForClass(tableName, targetClass);
    if (table_name == nil) {
        return nil;
    }
    
    __block sqlite_int64 lastRowId = 0;
    
    [self executeDB:^(FMDatabase *db) {
        FMResultSet *set = nil;
        set = [db executeQuery:[NSString stringWithFormat:@"SELECT row_id FROM %@ WHERE row_id=(SELECT max(row_id) FROM %@)",table_name,table_name ]];
        if (([set columnCount] > 0) && [set next]) {
            lastRowId = [[set stringForColumnIndex:0] longLongValue];
        }
        [set close];
    }];
    
    if (lastRowId > 0) {
        return [self firstModelFromTable:table_name where:[NSString stringWithFormat:@"row_id=%lld",lastRowId] forClass:targetClass];
    }

    return nil;
}
#pragma mark - insert
- (BOOL)insertModel:(NSObject *)model intoTable:(NSString *)tableName forClass:(Class)targetClass{
    
    NSString *table_name = tableNameForClass(tableName, targetClass);
    if (table_name == nil) {
        return NO;
    }
    
    if (![model isKindOfClass:targetClass]) {
        return NO;
    }
    
    if (![targetClass shouldInsert:model]) {
        return NO;
    }
    
    if(![_createdTableNames containsObject:table_name]){
        [self createTable:table_name forClass:targetClass];
    }
    
    
    ModelToTableMapping* mapping = [targetClass modelToTableMapping];
    
    NSMutableString* insertColumnsString = [NSMutableString stringWithCapacity:0];
    NSMutableString* insertValuesString = [NSMutableString stringWithCapacity:0];
    NSMutableArray* insertValues = [NSMutableArray arrayWithCapacity:mapping.count];
    
    
    for (int i = 0; i < mapping.count; i++){
        
        PropertyToColumnMapping* property = [mapping propertyToColumnMappingAtIndex:i];
        if([property.sqlColumnName isEmpty]){
            continue;
        }
        
        NSString *singleAutoIncPK =  singleAutoIncrementPrimaryKeyForClass(targetClass);
        
        if (singleAutoIncPK.length && [property.propertyName isEqualToString:singleAutoIncPK]) {
            continue;
        }
        
        id sqlValue = [targetClass dbValueFromModel:model withPropertyToColumnMapping:property];
        
        if (sqlValue && ![sqlValue isKindOfClass:[NSNull class]]) {
            [insertValues addObject:sqlValue];
        } else {
            continue;
        }
        
        
        if(insertColumnsString.length > 0) {
            [insertColumnsString appendString:@","];
            [insertValuesString appendString:@","];
        }
        
        [insertColumnsString appendString:property.sqlColumnName];
        [insertValuesString appendString:@"?"];
        
        
    }
    
    NSString* insertSQL = [NSString stringWithFormat:@"replace into %@(%@) values(%@)",table_name,insertColumnsString,insertValuesString];
    
    //callback
    [targetClass modelWillInsert:model];
    
    __block BOOL execute = NO;
    __block sqlite_int64 lastInsertRowId = 0;
    
    [self executeDB:^(FMDatabase *db) {
        execute = [db executeUpdate:insertSQL withArgumentsInArray:insertValues];
        lastInsertRowId= db.lastInsertRowId;
    }];
    
    model.row_id = (NSUInteger)lastInsertRowId;
    
    if(execute == NO){
        NSLog(@"database insert fail %@, sql:%@",NSStringFromClass(targetClass),insertSQL);
    }
    
    //callback
    [targetClass modelDidInsert:model result:execute];
    
    return execute;
}

-(BOOL)insertModelIfNotExists:(NSObject *)model intoTable:(NSString *)tableName forClass:(Class)targetClass{
    
    if (![self modelExists:model inTable:tableName forClass:targetClass]) {
        return [self insertModel:model intoTable:tableName forClass:targetClass];
    }
    return NO;
    
}


#pragma mark - delete
-(BOOL)deleteModel:(NSObject *)model fromTable:(NSString *)tableName forClass:(Class)targetClass{
    
    NSString *table_name = tableNameForClass(tableName, targetClass);
    if (table_name == nil) {
        return NO;
    }
    
    if (![model isKindOfClass:targetClass]) {
        return NO;
    }
    
    if (![targetClass shouldDelete:model]) {
        return NO;
    }
    
    [targetClass modelWillDelete:model];
    
    NSMutableString*  deleteSQL = [NSMutableString stringWithFormat:@"delete from %@ where ",table_name];
    NSMutableArray* outputWhereValues = [NSMutableArray new];
    NSString *indicator = indicatorStringForModelWithOutputColumnValues(model,outputWhereValues);
    
    if (indicator.length) {
        [deleteSQL appendString:indicator];
    } else {
        return NO;
    }
    
    
    BOOL result = [self executeUpdate:deleteSQL withArguments:outputWhereValues];
    
    [targetClass modelDidDelete:model result:result];
    
    return result;
}


-(BOOL)deleteModelsFromTable:(NSString *)tableName where:(id)where forClass:(Class)targetClass{
    
    NSString *table_name = tableNameForClass(tableName, targetClass);
    if (table_name == nil) {
        return NO;
    }
    
    
    NSMutableString* deleteSQL = [NSMutableString stringWithFormat:@"delete from %@ ",table_name];
    
    NSMutableArray * outputWhereValues = [NSMutableArray new];
    NSString *whereQuery = [targetClass whereQueryForInputValue:where outputColumnValues:outputWhereValues];
    if (whereQuery.length) {
        [deleteSQL appendFormat:@"%@",whereQuery];
    }
    return [self executeUpdate:deleteSQL withArguments:outputWhereValues];
}

#pragma mark - update
- (BOOL)updateTable:(NSString *)tableName withKeysAndValues:(NSDictionary *)keysAndValues where:(id)where forClass:(Class)targetClass{
    
    NSString *table_name = tableNameForClass(tableName, targetClass);
    if (table_name == nil) {
        return NO;
    }
    
    ModelToTableMapping *mapping = [targetClass modelToTableMapping];
    
    NSArray *keys = keysAndValues.allKeys;
    if (keys.count == 0) {
        return NO;
    }
    
    NSMutableString* updateColumnsString = [NSMutableString string];
    NSMutableArray* updateValues = [NSMutableArray arrayWithCapacity:keys.count];
    
    NSInteger index = 0;
    for(NSString *key in keys){
        
        PropertyToColumnMapping *mappingForPN = [mapping propertyToColumnMappingForPropertyName:key];
        PropertyToColumnMapping *mappingForCN = [mapping propertyToColumnMappingForColumnName:key];
        
        if (!mappingForPN && !mappingForCN) {
            continue;
        }
        
        NSString *columnName = key;
        NSString *propertyName = key;
        NSString *propertyType = nil;
        id value = keysAndValues[key];
        
        PropertyToColumnMapping *pcMapping = mappingForCN;
        if (mappingForPN && !mappingForCN) {
            pcMapping = mappingForPN;
            columnName = mappingForPN.sqlColumnName;
            propertyName = mappingForPN.propertyName;
            propertyType = mappingForPN.propertyType;
        } else {
            propertyName = mappingForCN.propertyName;
            propertyType = mappingForCN.propertyType;
        }
        
        id sqlValue = [[value class] dbValueFromPropertyValue:value withPropertyToColumnMapping:pcMapping];
        if (sqlValue){
            if (index > 0) {
                [updateColumnsString appendString:@","];
            }
            
            [updateColumnsString appendFormat:@"%@=?",columnName];
            [updateValues addObject:sqlValue];
            
            index++;
        }
    }
    
    
    NSMutableString* updateSQL = [NSMutableString stringWithFormat:@"update %@ set %@ ",table_name,updateColumnsString];
    
    NSString *whereQuery = [targetClass whereQueryForInputValue:where outputColumnValues:updateValues];
    if (whereQuery.length) {
        [updateSQL appendFormat:@"%@",whereQuery];
    }
    NSLog(@"%@ %@",updateSQL,updateValues);
    BOOL success = [self executeUpdate:updateSQL withArguments:updateValues];
    if(!success){
        NSLog(@"database update fail : %@   -----> update sql: %@",NSStringFromClass(targetClass),updateSQL);
    }
    
    return success;
    
}

- (BOOL)updateTable:(NSString *)tableName withModel:(NSObject *)model where:(id)where forClass:(Class)targetClass{
    
    if (![model isKindOfClass:targetClass]) {
        return NO;
    }
    
    NSArray *properties = propertiesToMapColumnsForClass(targetClass);
    if(![properties isSafeArray]) {
        return NO;
    }
    
    if (![targetClass shouldUpdate:model]) {
        return NO;
    }
    
    [targetClass modelWillUpdate:model];
    
    NSMutableDictionary *dic = [[NSMutableDictionary alloc]initWithCapacity:properties.count];
    for(NSString *property in properties){
        id value = [model valueForKey:property];
        if (value) {
            [dic setObject:value forKey:property];
        }
    }
    
    BOOL result = [self updateTable:tableName withKeysAndValues:dic where:where forClass:targetClass];
    
    [targetClass modelDidUpdate:model result:result];
    
    return result;
}

#pragma mark - exist

- (BOOL)modelExists:(NSObject *)model inTable:(NSString *)tableName forClass:(Class)targetClass{
    
    NSString *table_name = tableNameForClass(tableName, targetClass);
    if (table_name == nil) {
        return NO;
    }
    
    return [self firstModelFromTable:table_name where:indicatorForModel(model) orderBy:nil forClass:targetClass] != nil;
}

@end

