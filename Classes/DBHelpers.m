//
//  DBHelpers.m
//  Database
//
//  Created by MaSong on 15/8/20.
//  Copyright (c) 2015年 MaSong. All rights reserved.
//

#import "DBHelpers.h"
#import "NSObject+DB.h"

#pragma mark -
#pragma mark - inline methods

inline void execAsyncBlock(void(^block)(void)){
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),block);
}


inline void setAssociatedObject(id obj,const void *key,id associatedObj){
    if (obj) {
        objc_setAssociatedObject(obj, key,associatedObj, OBJC_ASSOCIATION_RETAIN_NONATOMIC);;
    }
}

inline id getAssociatedObject(id obj,const void *key){
    return obj ? objc_getAssociatedObject(obj, key) : nil ;
}

inline NSString* dbTypeFromObjcType(NSString *objcType){
    
    if([DBConvertedInt rangeOfString:objcType].length > 0){
        return DBTypeInt;
    }
    if ([DBConvertedFloat rangeOfString:objcType].length > 0) {
        return DBTypeFloat;
    }
    if ([DBConvertedBlob rangeOfString:objcType].length > 0) {
        return DBTypeBlob;
    }
    
    return DBTypeText;
}


inline NSString* tableNameForClass(NSString *tableName,Class targetClass){
    NSString *table_name = tableName.length ? tableName : [targetClass tableName];
    return  [table_name isEmpty] ? nil : table_name;
}

inline NSString* singleAutoIncrementPrimaryKeyForClass(Class targetClass){
    
    ModelToTableMapping * mapping = [targetClass modelToTableMapping];
    NSArray* primaryKeys = mapping.primaryKeys;
    
    if (primaryKeys.count == 0) {
        
        return DBRowId;
        
    } else if(primaryKeys.count == 1){
        NSString *pk = primaryKeys[0];
        PropertyToColumnMapping* property =  [mapping propertyToColumnMappingForPropertyName:pk];
        
        if([property.sqlColumnType isEqualToString:DBTypeInt]){
            if (![property.sqlColumnName isEqualToString:DBRowId]) {
                NSLog(@"Warnning!!!  %@ or %@ is set autoincrement column",property.sqlColumnName,property.propertyName);
            }
            return pk;
        }
    }
    
    return nil;
}



id indicatorForModel(NSObject *model){
    
    if (model.row_id > 0) {
        return [NSString stringWithFormat:@"row_id=%lu",(unsigned long)model.row_id];
    }
    
    NSString *singleAutoIncPK = singleAutoIncrementPrimaryKeyForClass(model.class);
    
    if (singleAutoIncPK) {
        NSUInteger singleAutoIncPKValue = [[((id)model) objectForKey:singleAutoIncPK] unsignedIntegerValue];
        if (singleAutoIncPKValue) {
            return [NSString stringWithFormat:@"%@=%lu",singleAutoIncPK,(unsigned long)singleAutoIncPKValue];
        }
    }
    
    
    ModelToTableMapping* mapping = [model.class modelToTableMapping];
    NSArray* primaryKeys = mapping.primaryKeys;
    
    if (primaryKeys.count) {
        
        NSMutableDictionary *indicatorDic = [NSMutableDictionary new];
        for (int i = 0; i < primaryKeys.count; i++) {
            
            NSString* name = primaryKeys[i];
            
            if ([name isNotEmpty]) {
                
                PropertyToColumnMapping *mappingForPN = [mapping propertyToColumnMappingForPropertyName:name];
                PropertyToColumnMapping *mappingForCN = [mapping propertyToColumnMappingForColumnName:name];
                
                if (!mappingForCN && !mappingForPN) {
                    continue;
                }
                
                id value = nil;
                if (!mappingForPN && mappingForCN) {//primary key is column name
                    
                    value = [model valueForKey:mappingForCN.propertyName];
                    name = mappingForPN.propertyName;
                    
                } else {//primary key is property name
                    
                    value = [model valueForKey:name];
                }
                
                if (value) {
                    [indicatorDic setObject:value forKey:name];
                }
                
            }
        }
        return indicatorDic;
    }
    return nil;
}

NSString* indicatorStringForModelWithOutputColumnValues(NSObject *model, NSMutableArray *outputColumnValues){
    
    if (model.row_id > 0) {
        return [NSString stringWithFormat:@"row_id=%lu",(unsigned long)model.row_id];
    }
    
    NSString *singleAutoIncPK = singleAutoIncrementPrimaryKeyForClass(model.class);
    
    if (singleAutoIncPK) {
        NSUInteger singleAutoIncPKValue = [[((id)model) objectForKey:singleAutoIncPK] unsignedIntegerValue];
        if (singleAutoIncPKValue) {
            return [NSString stringWithFormat:@"%@=%lu",singleAutoIncPK,(unsigned long)singleAutoIncPKValue];
        }
    }
    
    
    ModelToTableMapping* mapping = [model.class modelToTableMapping];
    NSArray* primaryKeys = mapping.primaryKeys;
    NSMutableString* indicator = [NSMutableString string];
    if(primaryKeys.count > 0){
        
        for (int i = 0; i < primaryKeys.count; i++) {
            
            NSString* name = primaryKeys[i];
            
            if ([name isNotEmpty]) {
                
                PropertyToColumnMapping *mappingForPN = [mapping propertyToColumnMappingForPropertyName:name];
                PropertyToColumnMapping *mappingForCN = [mapping propertyToColumnMappingForColumnName:name];
                
                if (!mappingForCN && !mappingForPN) {
                    continue;
                }
                
                id value = nil;
                if (!mappingForPN && mappingForCN) {//primary key is column name
                    
                    value = [model valueForKey:mappingForCN.propertyName];
                    name = mappingForPN.propertyName;
                    
                } else {//primary key is property name
                    
                    value = [model valueForKey:name];
                }
                
                value = [[model class] dbValueFromPropertyValue:value withPropertyToColumnMapping:mappingForCN];
                if(value){
                    if(indicator.length > 0){
                        [indicator appendString:@"and"];
                    }
                    
                    if(outputColumnValues){
                        [indicator appendFormat:@" %@=? ",name];
                        [outputColumnValues addObject:value];
                    } else {
                        [indicator appendFormat:@" %@='%@' ",name,value];
                    }
                }
                
            }
        }
        return indicator;
    }
    return nil;
}


NSArray *propertiesToMapColumnsForClass(Class targetClass){
    
    NSMutableArray *properties = [NSMutableArray new];
    if([[targetClass onlyPropertiesToMapColumns] count]){
        
        properties = (NSMutableArray *)[targetClass onlyPropertiesToMapColumns];
        
    } else {
        
        if ([targetClass shouldMapAllSelfPropertiesToTable]){
            properties = (NSMutableArray *)[targetClass getPropertyNamesContainParent:NO];
        }
        
        if ([targetClass shouldMapAllParentPropertiesToTable]) {
            [properties addObjectsFromArray:[[targetClass superclass] getPropertyNamesContainParent:YES]];
        }
    }
    
    if([[targetClass exceptPropertiesToMapColumns] count]){
        
        for(NSString *e in [targetClass exceptPropertiesToMapColumns]){
            if ([properties containsObject:e]) {
                [properties removeObject:e];
            }
        }
    }
    
    if(properties.count == 0) {
        NSLog(@"Error!! properties count is 0");
        return nil;
    }
    
    return properties;
}




#pragma mark -
#pragma mark - FMDatabase (DBHelper)
@implementation FMDatabase (DBHelper)

+ (FMDatabase *)createDatabase:(NSString *)dstPath{
    return [FMDatabase databaseWithPath:dstPath];
}

+ (FMDatabase *)copyDatabase:(NSString *)srcPath toPath:(NSString *)dstPath{
    
    if ([srcPath isNotEmpty] && [dstPath isNotEmpty]) {
        NSFileManager *fManager = [NSFileManager defaultManager];
        
        if ([fManager fileExistsAtPath:dstPath]) {
            return [FMDatabase databaseWithPath:dstPath];
        }
        
        if ([fManager fileExistsAtPath:srcPath]) {
            NSError *error;
            
            BOOL success = [fManager copyItemAtPath:srcPath toPath:dstPath error:&error];
            if (success) {
                return [FMDatabase databaseWithPath:dstPath];
            } else {
                return nil;
            }
        }
    }
    return nil;
}

+ (BOOL)removeDatabase:(NSString *)dstPath{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    return [fileManager removeItemAtPath:dstPath error:nil];
}


#pragma mark -
#pragma mark - table info
/*
 * 查看所有表名
 */
- (NSArray *)allTableNames {
    
    NSMutableArray *allTableName = [NSMutableArray new];
    [self getAllTableInfoForKey:@"tbl_name" outPut:allTableName];
    if (allTableName.count) {
        return allTableName;
    }
    
    return nil;
}

//
// {
// name = users;
// rootpage = 2;
// sql = "CREATE TABLE users (id integer primary key autoincrement, user text, password text)";
// "tbl_name" = users;
// type = table;
// }
- (NSArray *)allTableInfos {
    
    NSMutableArray *allTableInfo = [NSMutableArray new];
    
    [self getAllTableInfoForKey:nil outPut:allTableInfo];
    
    if (allTableInfo.count) {
        return allTableInfo;
    }
    
    return nil;
}

- (NSString *)sqlStatementForTable:(NSString *)tableName{
    if ([tableName isNotEmpty]) {
        
        FMResultSet *rs = [self executeQuery:[NSString stringWithFormat:@"select sql from sqlite_master where type='table' and tbl_name='%@'", tableName]];
        
        NSString *sql = nil;
        
        while ([rs next]) {
            
            NSDictionary *resultDictionary = [rs resultDictionary];
            if ([resultDictionary isSafeDic]) {
                sql = [resultDictionary objectForKey:@"sql"];
            }
        }
        
        [rs close];
        
        return sql;
    }
    
    return nil;
}

/*
 * 判断一个表是否存在；
 */
- (BOOL)tableExists:(NSString *)tableName {
    if ([tableName isNotEmpty]) {
        return [[self allTableNames] containsObject:tableName ];
    }
    return NO;
}


- (void)getAllTableInfoForKey:(NSString *)key outPut:(NSMutableArray *)outPut{
    
    FMResultSet *rs = [self executeQuery:@"SELECT * FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';"];
    
    while ([rs next]) {
        
        NSDictionary *resultDictionary = [rs resultDictionary];
        if (![resultDictionary isKindOfClass:[NSNull class]] &&
            [resultDictionary isKindOfClass:[NSDictionary class]] &&
            resultDictionary.count) {
            if ([key isNotEmpty]) {
                [outPut addObject:[resultDictionary objectForKey:key]];
            } else {
                [outPut addObject:resultDictionary];
            }
            
        }
    }
    
    [rs close];
    
}

#pragma mark -
#pragma mark - Dump

- (NSString *)getTableDumpString:(NSString *)tableName {
    
    if ([tableName isNotEmpty]) {
        
        NSArray *allTableName = [self allTableNames];
        
        if ([allTableName containsObject:tableName]) {
            
            NSMutableString *dump = [[NSMutableString alloc] initWithCapacity:256];
            
            //get table content
            NSArray *tableContent = [self selectColumns:nil fromTable:tableName where:nil groupBy:nil orderBy:nil limit:0 offset:0];
            
            //table name and all table column name
            NSMutableString *tableNameAndAllColumName = [NSMutableString new];
            if (tableContent.count) {
                
                NSDictionary *firstRecord = tableContent[0];
                //keys are column names
                NSArray *keys = [firstRecord allKeys];
                
                if (keys.count == 0) {
                    return nil;
                }
                
                [tableNameAndAllColumName appendString:[NSString stringWithFormat:@"%@ (",tableName]];
                
                //loop through all keys (aka column names)
                NSEnumerator *enumerator = [keys objectEnumerator];
                id obj;
                while (obj = [enumerator nextObject]) {
                    [tableNameAndAllColumName appendString:[NSString stringWithFormat:@"%@,",obj]];
                }
                
                [tableNameAndAllColumName replaceLastCharacterWithString:@")"];
                
            }
            
            //table values
            for (int i = 0; i < [tableContent count]; i++) {
                NSDictionary *record = [tableContent objectAtIndex:i];
                
                //values are column values
                NSArray *values = [record allValues];
                
                [dump appendString:[NSString stringWithFormat:@"%@ values (",tableNameAndAllColumName]];
                
                
                NSEnumerator *enumerator = [values objectEnumerator];
                id obj;
                while (obj = [enumerator nextObject]) {
                    //if it's a number (integer or float)
                    if ([obj isKindOfClass:[NSNumber class]]){
                        [dump appendString:[NSString stringWithFormat:@"%@,",[obj stringValue]]];
                    }
                    //if it's a null
                    else if ([obj isKindOfClass:[NSNull class]]){
                        [dump appendString:@"null,"];
                    }
                    //else is a string ;)
                    else{
                        [dump appendString:[NSString stringWithFormat:@"'%@',",obj]];
                    }
                    
                }
                
                [dump replaceLastCharacterWithString:@");\n"];
                
            }
            return dump;
        }
    }
    return nil;
    
}

- (NSString *)getDatabaseDumpString{
    
    NSMutableString *dump = [[NSMutableString alloc] initWithCapacity:256];
    
    // first get all table information
    
    NSArray *infors = [self allTableInfos];
    
    //loop through all tables
    for (int i = 0; i < [infors count]; i++) {
        
        NSDictionary *tableInfo = infors[i];
        
        //get table name
        NSString *tableName = [tableInfo objectForKey:@"tbl_name"];
        
        NSString *dumpTableInfo = [self getTableDumpString:tableName];
        if (dumpTableInfo.length) {
            [dump appendString:[NSString stringWithFormat:@"%@",dumpTableInfo]];
        }
        
    }
    
    return dump;
}

- (BOOL)importDatabase:(NSString *)srcPath shouldImportTable:(BOOL(^)(NSString *tableName))shouldImportTable{
    return [self importDatabase:srcPath onlyImportTablesThoseNotExist:NO shouldImportTable:shouldImportTable];
}

- (BOOL)importTheWholeDatabase:(NSString *)srcPath {
    return [self importDatabase:srcPath onlyImportTablesThoseNotExist:NO shouldImportTable:nil];
}

- (BOOL)onlyImportTablesThoseNotExist:(NSString *)srcPath{
    return [self importDatabase:srcPath onlyImportTablesThoseNotExist:YES shouldImportTable:nil];
}

- (BOOL)importDatabase:(NSString *)srcPath onlyImportTablesThoseNotExist:(BOOL)onlyImportTablesThoseNotExist shouldImportTable:(BOOL(^)(NSString *tableName))shouldImportTable {
    if ([srcPath isNotEmpty]) {
        NSFileManager *fManager = [NSFileManager defaultManager];
        
        if ([fManager fileExistsAtPath:srcPath]) {
            
            FMDatabase *srcDB = [FMDatabase databaseWithPath:srcPath];
            [srcDB open];
            
            NSArray *srcDBTables = [srcDB allTableNames];
            if (srcDBTables.count == 0) {
                return NO;
            }
            
            NSArray *selfTables = [self allTableNames];
            
            for(NSString *tableName in srcDBTables){
                
                if (shouldImportTable) {
                    BOOL import = shouldImportTable(tableName);
                    if (!import) {
                        continue;
                    }
                }
                
                if ([selfTables containsObject:tableName]) {
                    NSLog(@" Warning!!! Table : [ %@ ] has Existed",tableName);
                    if (onlyImportTablesThoseNotExist) {
                        continue;
                    }
                } else {
                    
                    NSString *sqlStatement = [srcDB sqlStatementForTable:tableName];
                    
                    if (sqlStatement.length == 0) {
                        continue;
                    }
                    // 错误信息
                    char *errmsg = NULL;
                    
                    //创建表
                    int ret = sqlite3_exec(self.sqliteHandle, [sqlStatement UTF8String], NULL, NULL, &errmsg);
                    if (ret != SQLITE_OK) {
                        NSLog(@"create tbale error: %s", errmsg);
                        continue;
                    }
                }
                
                
                NSString *tableDumpString = [srcDB getTableDumpString:tableName];
                
                NSArray *array = [tableDumpString componentsSeparatedByString:@"\n"];
                
                [self beginTransaction];
                for(NSString *str in array){
                    if ([str isNotEmpty]) {
                        [self executeUpdate:[NSString stringWithFormat:@"replace into %@",str]];
                    }
                }
                BOOL success = [self commit];
                if (!success) {
                    NSLog(@"Error! replace into [ %@ ] ,commit failed",tableName);
                    return NO;
                }
            }
            
            [srcDB close];
            
            return YES;
        }
    }
    return NO;
}

- (BOOL)exportDatabase:(NSString *)dstPath{
    return [FMDatabase copyDatabase:self.databasePath toPath:dstPath] != nil;
}



- (NSMutableArray*)selectColumns:(id)columns
                           fromTable:(NSString*)tableName
                           where:(id)where
                         groupBy:(NSString *)groupBy
                         orderBy:(NSString *)orderBy
                           limit:(int)limit
                          offset:(int)offset{
    
    NSMutableArray *values = [NSMutableArray new];
    NSMutableString *query = [NSMutableString queryStringForColumns:columns table:tableName where:where  groupBy:groupBy orderBy:orderBy limit:limit  offset:offset outputColumnValues:values];
    
    if (query) {
        
        FMResultSet *rs = nil;
        if (values.count) {
            rs = [self executeQuery:query withArgumentsInArray:values];
        } else {
            rs = [self executeQuery:query];
        }
        NSMutableArray *queryResult = [NSMutableArray new];
        while ([rs next]) {
            
            NSDictionary *resultDictionary = [rs resultDictionary];
            if ([resultDictionary isSafeDic]) {
                [queryResult addObject:resultDictionary];
            }
            
        }
        [rs close];
        NSLog(@"%@ => result count : %lu",query,(unsigned long)queryResult.count);
        
        if (queryResult.count) {
            return queryResult;
        }
    }
    return nil;
}


- (BOOL)dropTable:(NSString *)tableName{
    BOOL sueecss = NO;
    if ([tableName isNotEmpty]) {
        sueecss = [self executeUpdate:[NSString stringWithFormat:@"drop table %@",tableName]];
    }
    
    return sueecss;
    
}


@end



#pragma mark -
#pragma mark - NSObject(DBHelper)
@implementation NSObject(DBHelper)
+ (NSArray*)getPropertyNames{
    return [self getPropertyNamesContainParent:YES];
}

+(NSArray*)getPropertyNamesContainParent:(BOOL)containParent{
    NSMutableArray *names = [NSMutableArray new];
    [self getPropertyNames:names propertyTypes:nil containParent:containParent];
    if (names.count) {
        return names;
    }
    return nil;
}


+ (void)getPropertyNames:(NSMutableArray *)oPropertyNames propertyTypes:(NSMutableArray *) oPropertyTypes  containParent:(BOOL)containParent{
    
    Class targetClass = self.class;
    
    if (targetClass == [NSObject class]){
        return;
    }
    
    unsigned int outCount, i;
    objc_property_t *properties = class_copyPropertyList(targetClass, &outCount);
    for (i = 0; i < outCount; i++) {
        
        objc_property_t property = properties[i];
        
        NSString *propertyName = [NSString stringWithCString:property_getName(property) encoding:NSUTF8StringEncoding];
        
        id propertyType = [self objcTypeFromProperty:property];
        
        if(propertyName.length && [propertyType length]){
            if (oPropertyNames) {
                [oPropertyNames addObject:propertyName];
            }
            
            if (oPropertyTypes) {
                [oPropertyTypes addObject:propertyType];
            }
        }
    }
    free(properties);
    
    if(containParent && [self superclass] != [NSObject class]){
        [[self superclass] getPropertyNames:oPropertyNames propertyTypes:oPropertyTypes containParent:containParent];
    }
}


+(NSString *)objcTypeFromProperty:(objc_property_t)property{
    
    NSString *attributesString = [NSString stringWithCString: property_getAttributes(property) encoding:NSUTF8StringEncoding];
    
    //    NSLog(@"propertyAttributesString :  %@",attributesString);
    
    if ([attributesString hasPrefix:@"T@"]) {
        
        NSString* type = [attributesString substringWithRange:NSMakeRange(3, [attributesString rangeOfString:@","].location - 4)];
        
        if(type == nil || type.length == 0) {
            
            type = @"NSString";
            
        } else if([type hasSuffix:@">"]) {
            
            NSRange range = [attributesString rangeOfString:@"<"];
            if (range.length > 0) {
                type = [type substringToIndex:range.location];
            }
        }
        return type;
        
    } else if([attributesString hasPrefix:@"T{"]) {
        
        NSString *type = [attributesString substringWithRange:NSMakeRange(2, [attributesString rangeOfString:@"="].location - 2)];
        if (type.length) {
            return type;
        }
        
    } else {
        attributesString = [attributesString lowercaseString];
        
        if ([attributesString hasPrefix:@"ti"] || [attributesString hasPrefix:@"tb"]){
            
            return @"int";
            
        } else if ([attributesString hasPrefix:@"tf"]){
            
            return @"float";
            
        } else if([attributesString hasPrefix:@"td"]) {
            
            return @"double";
            
        } else if([attributesString hasPrefix:@"tl"] || [attributesString hasPrefix:@"tq"]){
            
            return @"long";
            
        } else if ([attributesString hasPrefix:@"tc"]) {
            
            return @"char";
            
        } else if([attributesString hasPrefix:@"ts"]){
            
            return  @"short";
            
        } else {
            
            return @"NSString";
        }
    }
    return @"NSString";
}



- (BOOL)isSafeObj{
    return self && ![self isKindOfClass:[NSNull class]];
}

- (BOOL)isSafeString{
    return [self isSafeObj] && [self isKindOfClass:[NSString class]] && [(NSString *)self length];
}

- (BOOL)isSafeArray{
    return [self isSafeObj] && [self isKindOfClass:[NSArray class]] && [(NSArray *)self count];
}

- (BOOL)isSafeDic{
    return [self isSafeObj] && [self isKindOfClass:[NSDictionary class]] && [(NSDictionary *)self count];
}


- (NSData *)jsonData{
    if(self && [NSJSONSerialization isValidJSONObject:self]){
        
        NSData* jsonData = [NSJSONSerialization dataWithJSONObject:self options:0 error:nil];
        if(jsonData.length > 0){
            return jsonData;
        }
    }
    return nil;
}

- (NSString*)jsonString{
    
    NSData *jsonData = [self jsonData];
    if (jsonData.length) {
        NSString *jsonString = [[NSString alloc]initWithData:jsonData encoding:NSUTF8StringEncoding];
        return jsonString;
    }
    
    if ([self isKindOfClass:[NSString class]]) {
        return (NSString *)self;
    }
    
    return nil;
}

- (id)objectFromJsonValue{
    
    NSData *jsonData = nil;
    if([self isKindOfClass:[NSString class]]){
        
        jsonData = [(NSString *)self dataUsingEncoding:NSUTF8StringEncoding];
        
    } else if([self isKindOfClass:[NSData class]]) {
        
        jsonData = (NSData *)self;
    }
    
    if(jsonData.length > 0) {
        
        return [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    }
    return nil;
}

+ (NSMutableString *)whereQueryForInputValue:(id)where
                          outputColumnValues:(NSMutableArray *)values{
    
    NSMutableString *whereString = [NSMutableString new];
    if ([where isSafeDic]) {
        NSMutableString *wherekey = [NSMutableString stringWithCapacity:0];
        NSDictionary *dic = where;
        
        NSArray *keys = dic.allKeys;
        
        for (NSInteger i = 0; i < keys.count; i++) {
            NSString *key = [keys objectAtIndex:i];
            id va = [dic objectForKey:key];
            
            if ([va isKindOfClass:[NSArray class]]) {
                NSArray *vlist = va;
                
                if (vlist.count == 0) {
                    continue;
                }
                
                if (wherekey.length > 0) {
                    [wherekey appendString:@" and"];
                }
                
                [wherekey appendFormat:@" %@ in(", key];
                
                for (NSInteger j = 0; j < vlist.count; j++) {
                    [wherekey appendString:@"?"];
                    
                    if (j == vlist.count - 1) {
                        [wherekey appendString:@")"];
                    } else {
                        [wherekey appendString:@","];
                    }
                    
                    [values addObject:[vlist objectAtIndex:j]];
                }
            } else {
                if (wherekey.length > 0) {
                    [wherekey appendFormat:@" and %@=?", key];
                } else {
                    [wherekey appendFormat:@" %@=?", key];
                }
                
                [values addObject:va];
            }
        }
        [whereString appendFormat:@" where %@", wherekey];
    } else if ([where isSafeString]) {
        [whereString appendFormat:@" where %@", where];
    }
    return whereString;
}

+ (NSMutableString *)queryStringForColumns:(id)columns
                                     table:(NSString*)tableName
                                     where:(id)where
                                   groupBy:(NSString *)groupBy
                                   orderBy:(NSString *)orderBy
                                     limit:(int)limit
                                    offset:(int)offset
                        outputColumnValues:(NSMutableArray *)values{
    
    
    
    NSString *columnsString = nil;
    NSUInteger columnCount = 0;
    
    if ([columns isSafeArray]) {
        columnCount = [columns count];
        columnsString = [columns componentsJoinedByString:@","];
        
    } else if ([columns isSafeString]){
        columnsString = columns;
        NSArray *array = [columns componentsSeparatedByString:@","];
        columnCount = [array count];
    }
    
    if (columnCount == 0) {
        columnsString = @"*";
    }
    
    if (![tableName isSafeString]) {
        NSLog(@"TableName is nil");
        return nil;
    }
    NSMutableString *query = [NSMutableString stringWithFormat:@"select %@ from %@ ",columnsString,tableName];
    
    
    id whereQuery = [NSMutableString whereQueryForInputValue:where outputColumnValues:values];
    if ([whereQuery isSafeString]) {
        [query appendFormat:@"%@", whereQuery];
    }
    
    if([groupBy isNotEmpty]){
        [query appendFormat:@" group by %@",groupBy];
    }
    
    if([orderBy isNotEmpty]){
        [query appendFormat:@" order by %@",orderBy];
    }
    
    if(limit > 0){
        [query appendFormat:@" limit %d offset %d",limit,offset];
    } else if(offset > 0) {
        [query appendFormat:@" limit %d offset %d",INT_MAX,offset];
    }
    
    return query;
}

//convert db value to objc model value
+ (id)modelValueFromDBValue:(id)dbValue withPropertyToColumnMapping:(PropertyToColumnMapping *)mapping{
    
    id returnValue = nil;
    
    NSString *type = mapping.propertyType;
    
    Class propertyTypeClass = NSClassFromString(mapping.propertyType);
    
    if (propertyTypeClass == nil) {
        
        if([DBConvertedFloat rangeOfString:type].location != NSNotFound){
            
            double number = [dbValue doubleValue];
            returnValue = [NSNumber numberWithDouble:number];
            
        } else if([DBConvertedInt rangeOfString:type].location != NSNotFound) {
            
            if([type isEqualToString:@"long"]) {
                
                long long number = [dbValue longLongValue];
                returnValue = [NSNumber numberWithLongLong:number];
            } else {
                
                int number = [dbValue intValue];
                returnValue = [NSNumber numberWithInteger:number];
            }
        } else if([type isEqualToString:@"CGRect"]) {
            
            CGRect rect = CGRectFromString(dbValue);
            returnValue = [NSValue valueWithCGRect:rect];
            
        } else if([type isEqualToString:@"CGPoint"]) {
            
            CGPoint point = CGPointFromString(dbValue);
            returnValue = [NSValue valueWithCGPoint:point];
            
        } else if([type isEqualToString:@"CGSize"]) {
            
            CGSize size = CGSizeFromString(dbValue);
            returnValue = [NSValue valueWithCGSize:size];
            
        } else if([type isEqualToString:@"_NSRange"]) {
            
            NSRange range = NSRangeFromString(dbValue);
            returnValue = [NSValue valueWithRange:range];
        }
        
    } else if([propertyTypeClass isSubclassOfClass:[NSString class]]) {
        
        returnValue = dbValue;
        
    } else if([propertyTypeClass isSubclassOfClass:[NSNumber class]]) {
        
        returnValue = [NSNumber numberWithDouble:[dbValue doubleValue]];
        
    } else if([propertyTypeClass isSubclassOfClass:[NSDate class]]) {
        
        NSString* dateStr = [dbValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        returnValue = [NSDate dateFromString:dateStr withDateFormatter:[self.class dateFormatterString]];
        
    } else if([propertyTypeClass isSubclassOfClass:[UIColor class]]){
        
        NSString* color = dbValue;
        NSArray* array = [color componentsSeparatedByString:@","];
        float r,g,b,a;
        r = [[array objectAtIndex:0] floatValue];
        g = [[array objectAtIndex:1] floatValue];
        b = [[array objectAtIndex:2] floatValue];
        a = [[array objectAtIndex:3] floatValue];
        
        returnValue = [UIColor colorWithRed:r green:g blue:b alpha:a];
        
        
    } else if([propertyTypeClass isSubclassOfClass:[NSValue class]]) {
        
        NSString* valueName = dbValue;
        NSString* dataPath = [self.class dataPathForData:valueName];
        
        if([NSFileManager fileExistsAtPath:dataPath]){
            NSData* data = [NSData dataWithContentsOfFile:dataPath];
            returnValue = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        }
        
    } else if([propertyTypeClass isSubclassOfClass:[UIImage class]]) {
        
        NSString* imgName = dbValue;
        NSString* imgPath = [self.class imagePathForImage:imgName];
        
        if([NSFileManager fileExistsAtPath:imgPath]){
            UIImage* img = [[UIImage alloc] initWithContentsOfFile:imgPath];
            returnValue = img;
        }
        
    } else if([propertyTypeClass isSubclassOfClass:[NSData class]]) {
        
        NSString* dataName = dbValue;
        NSString* dataPath = [self.class dataPathForData:dataName];
        
        if([NSFileManager fileExistsAtPath:dataPath]){
            NSData* data = [NSData dataWithContentsOfFile:dataPath];
            returnValue = data;
        }
        
    } else if ([propertyTypeClass isSubclassOfClass:[NSArray class]] ||
               [propertyTypeClass isSubclassOfClass:[NSDictionary class]]){
        
        return [dbValue objectFromJsonValue];
        
    } else {
        returnValue = nil;
    }
    
    return returnValue;
}

+ (id)dbValueFromModel:(id)model withPropertyToColumnMapping:(PropertyToColumnMapping *)mapping{
    
    id objcValue = [model valueForKey:mapping.propertyName];
    return [self dbValueFromPropertyValue:objcValue withPropertyToColumnMapping:mapping];
}
//convert objc value to db value
+ (id)dbValueFromPropertyValue:(id)objcValue withPropertyToColumnMapping:(PropertyToColumnMapping *)mapping{
    
    id returnValue = objcValue;
    if (objcValue == nil) {
        return nil;
    }
    
    if([objcValue isKindOfClass:[NSString class]]) {
        
        returnValue = objcValue;
        
    } else if([objcValue isKindOfClass:[NSNumber class]]) {
        
        returnValue = [objcValue stringValue];
        
    } else if([objcValue isKindOfClass:[NSDate class]]) {
        
        returnValue = [NSDate stringFromDate:objcValue withDateFormatter:[self.class dateFormatterString]];
        returnValue = [returnValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
    } else if([objcValue isKindOfClass:[UIColor class]]){
        
        UIColor* color = objcValue;
        CGFloat r,g,b,a;
        [color getRed:&r green:&g blue:&b alpha:&a];
        returnValue = [NSString stringWithFormat:@"%.3f,%.3f,%.3f,%.3f",r,g,b,a];
        
    } else if([objcValue isKindOfClass:[NSValue class]]) {
        
        NSString *type = mapping.propertyType;
        if([type isEqualToString:@"CGRect"]) {
            
            returnValue = NSStringFromCGRect([objcValue CGRectValue]);
            
        } else if([type isEqualToString:@"CGPoint"]){
            
            returnValue = NSStringFromCGPoint([objcValue CGPointValue]);
            
        } else if([type isEqualToString:@"CGSize"]){
            
            returnValue = NSStringFromCGSize([objcValue CGSizeValue]);
            
        } else if([type isEqualToString:@"_NSRange"]){
            
            returnValue = NSStringFromRange([objcValue rangeValue]);
            
        } else {
            
            NSData *data = [NSKeyedArchiver archivedDataWithRootObject:objcValue];
            NSString* valueName = [data md5String];
            execAsyncBlock(^{
                
                NSString* dataPath = [self.class dataPathForData:valueName];
                if(![NSFileManager fileExistsAtPath:dataPath]){
                    [data writeToFile:dataPath atomically:YES];
                }
            });
            
            returnValue = valueName;
        }
        
    } else if([objcValue isKindOfClass:[UIImage class]]) {
        
        NSData* data = UIImageJPEGRepresentation(objcValue, 1);
        NSString* imgName = [data md5String];
        
        execAsyncBlock(^{
            
            NSString* dataPath = [self.class imagePathForImage:imgName];
            if(![NSFileManager fileExistsAtPath:dataPath]){
                [data writeToFile:dataPath atomically:YES];
            }
        });
        
        returnValue = imgName;
        
    } else if([objcValue isKindOfClass:[NSData class]]) {
        
        NSString* dataName = [objcValue md5String];
        
        execAsyncBlock(^{
            
            NSString* dataPath = [self.class dataPathForData:dataName];
            if(![NSFileManager fileExistsAtPath:dataPath]){
                [objcValue writeToFile:dataPath atomically:YES];
            }
        });
        
        returnValue = dataName;
        
    } else if ([objcValue isKindOfClass:[NSArray class]] ||
               [objcValue isKindOfClass:[NSDictionary class]]){
        
        returnValue = [objcValue jsonString];
        
    } else {
        returnValue = nil;
    }
    
    return returnValue;
}


+(ModelToTableMapping*)modelToTableMapping{
    static __strong NSMutableDictionary* oncePropertyDic;
    static __strong NSRecursiveLock* lock;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        lock = [[NSRecursiveLock alloc]init];
        oncePropertyDic = [[NSMutableDictionary alloc]initWithCapacity:8];
    });
    
    ModelToTableMapping* mapping = nil;
    [lock lock];
    
    mapping = [oncePropertyDic objectForKey:NSStringFromClass(self)];
    if(mapping == nil){
        NSMutableArray* propertyNames = [NSMutableArray array];
        NSMutableArray* propertyTypes = [NSMutableArray array];
        
        
        if ([self shouldMapAllSelfPropertiesToTable] &&
            [self class] != [NSObject class]){
            
            [self getPropertyNames:propertyNames propertyTypes:propertyTypes containParent:NO];
        }
        
        
        if([self shouldMapAllParentPropertiesToTable] &&
           ([self superclass] != [NSObject class])){
            ModelToTableMapping* superMapping = [[self superclass] modelToTableMapping];
            
            for (int i = 0; i < superMapping.count; i++) {
                
                PropertyToColumnMapping* pcMap = [superMapping propertyToColumnMappingAtIndex:i];
                if(pcMap.propertyName && pcMap.propertyType && ![pcMap.propertyName isEqualToString:DBRowId]){
                    [propertyNames addObject:pcMap.propertyName];
                    [propertyTypes addObject:pcMap.propertyType];
                }
            }
        }
        
        
        NSMutableDictionary *nameTypeDic = [[NSMutableDictionary alloc]initWithObjects:propertyTypes forKeys:propertyNames];
        
        if ([self onlyPropertiesToMapColumns]) {
            for(NSString *name in nameTypeDic.allKeys){
                if (![[self onlyPropertiesToMapColumns] containsObject:name]) {
                    [nameTypeDic removeObjectForKey:name];
                }
            }
        }
        
        if ([self exceptPropertiesToMapColumns]) {
            for(NSString *name in nameTypeDic.allKeys){
                if ([[self exceptPropertiesToMapColumns] containsObject:name]) {
                    [nameTypeDic removeObjectForKey:name];
                }
            }
        }
        
        if ([nameTypeDic count]) {
            
            NSArray* primaryKeys = [self primaryKeys];
            if(primaryKeys.count == 0) {
                primaryKeys = [NSArray arrayWithObject:DBRowId];
            }
            
            mapping = [[ModelToTableMapping alloc]initWithPropertyNames:nameTypeDic.allKeys propertyTypes:nameTypeDic.allValues primaryKeys:primaryKeys propertyToColumnMappings:[self propertyToColumnMappings]];
            [oncePropertyDic setObject:mapping forKey:NSStringFromClass(self)];
        }
        
    }
    [lock unlock];
    return mapping;
    
}


@end

#pragma mark -
#pragma mark - NSMutableString
@implementation NSMutableString (DBHelper)

- (void)replaceLastCharacterWithString:(NSString *)str {
    if (self.length > 1) {
        NSRange range;
        range.length = 1;
        range.location = [self length] - 1;
        [self replaceCharactersInRange:range withString:[str isNotEmpty] ? str : @""];
    }
}


@end
#pragma mark -
#pragma mark - NSString

@implementation NSString (DBHelper)

- (NSString *)trimmedString {
    return [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSString *)md5String {
    
    const char *cStr = [self UTF8String];
    if (cStr == NULL){
        cStr = "";
    }
    unsigned char result[16];
    CC_MD5( cStr, (CC_LONG)strlen(cStr), result );
    
    NSString * str = [NSString
                      stringWithFormat: @"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
                      result[0], result[1],
                      result[2], result[3],
                      result[4], result[5],
                      result[6], result[7],
                      result[8], result[9],
                      result[10], result[11],
                      result[12], result[13],
                      result[14], result[15]
                      ];
    return  [str lowercaseString] ;
}

- (BOOL)isNotEmpty{
    return self && ![[self trimmedString] isEqualToString:@""];
}

- (BOOL)isEmpty{
    return ![self isNotEmpty];
}

@end

#pragma mark -
#pragma mark - NSData

@implementation NSData (DBHelper)

- (NSString *)md5String {
    
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(self.bytes, (CC_LONG)self.length, digest );
    
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    
    for(int i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
        [output appendFormat:@"%02X", digest[i]];
    
    return [output lowercaseString];
}

@end
#pragma mark -
#pragma mark - NSFileManager
@implementation NSFileManager(DBHelper)
+(NSString *)documentPath {
    return NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
}

+ (NSString *)createDirInDocument:(NSString *)pathName{
    
    NSString* dirPath = [[NSFileManager documentPath] stringByAppendingPathComponent:pathName];
    BOOL isDir = NO;
    BOOL isCreated = [[NSFileManager defaultManager] fileExistsAtPath:dirPath isDirectory:&isDir];
    if (!isCreated || !isDir) {
        NSError* error = nil;
        BOOL success = [[NSFileManager defaultManager] createDirectoryAtPath:dirPath withIntermediateDirectories:YES attributes:nil error:&error];
        if(success == NO)
            NSLog(@"create dir error: %@",error.debugDescription);
    }
    return dirPath;
}

+(BOOL)fileExistsAtPath:(NSString *)filepath {
    return [[NSFileManager defaultManager] fileExistsAtPath:filepath];
}

+(BOOL)removeFileAtPath:(NSString *)filepath {
    return [[NSFileManager defaultManager] removeItemAtPath:filepath error:nil];
}
@end
#pragma mark -
#pragma mark - NSDate
@implementation NSDate(DBHelper)
+ (NSDate *)dateFromString:(NSString *)dateString withDateFormatter:(NSString *)formatter{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    if (formatter) {
        [dateFormatter setDateFormat:formatter];
    } else {
        [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    }
    return [dateFormatter dateFromString:dateString];
}

+ (NSString *)stringFromDate:(NSDate *)date withDateFormatter:(NSString *)formatter {
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    if (formatter) {
        [dateFormatter setDateFormat:formatter];
    } else {
        [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    }
    return [dateFormatter stringFromDate:date];
}
@end

