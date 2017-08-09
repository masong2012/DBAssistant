//
//  DBHelpers.h
//  Database
//
//  Created by MaSong on 15/8/20.
//  Copyright (c) 2015年 MaSong. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <CommonCrypto/CommonDigest.h>
#import <UIKit/UIKit.h>
#import <sqlite3.h>
#import "FMDB.h"
#import "DBMappings.h"

//=============
@interface FMDatabase (DBHelper)

+ (FMDatabase *)createDatabase:(NSString *)dstPath;
+ (FMDatabase *)copyDatabase:(NSString *)srcPath toPath:(NSString *)dstPath;

+ (BOOL)removeDatabase:(NSString *)dstPath;

- (BOOL)importDatabase:(NSString *)srcPath shouldImportTable:(BOOL(^)(NSString *tableName))shouldImportTable;
- (BOOL)importTheWholeDatabase:(NSString *)srcPath ;
- (BOOL)onlyImportTablesThoseNotExist:(NSString *)srcPath;
- (BOOL)exportDatabase:(NSString *)dstPath;


- (NSArray *)allTableNames;
- (NSArray *)allTableInfos;
- (BOOL)tableExists:(NSString *)tableName;
- (NSString *)sqlStatementForTable:(NSString *)tableName;

- (NSString *)getTableDumpString:(NSString *)tableName;
- (NSString *)getDatabaseDumpString;


- (NSMutableArray*)selectColumns:(id)columns
                           fromTable:(NSString*)tableName
                           where:(id)where
                         groupBy:(NSString *)groupBy
                         orderBy:(NSString *)orderBy
                           limit:(int)limit
                          offset:(int)offset;

- (BOOL)dropTable:(NSString *)tableName;
@end



//=============
@interface NSMutableString (DBHelper)
- (void)replaceLastCharacterWithString:(NSString *)str;
@end

//=============
@interface NSString (DBHelper)
- (NSString *)trimmedString;
- (NSString *)md5String;
- (BOOL)isNotEmpty;
- (BOOL)isEmpty;
@end

//=============
@interface NSData (DBHelper)
- (NSString *)md5String;
@end

//=============
@interface NSFileManager(DBHelper)
+ (NSString*)documentPath;
+ (NSString *)createDirInDocument:(NSString *)pathName;
+ (BOOL)fileExistsAtPath:(NSString *)filepath;
+ (BOOL)removeFileAtPath:(NSString *)filepath;
@end

//=============
@interface NSDate(DBHelper)
+ (NSDate *)dateFromString:(NSString *)dateString withDateFormatter:(NSString *)formatter;

+ (NSString *)stringFromDate:(NSDate *)date withDateFormatter:(NSString *)formatter;

@end


//=============
@interface NSObject (DBHelper)

+ (NSArray*)getPropertyNames;
+ (NSArray*)getPropertyNamesContainParent:(BOOL)containParent;
+ (void)getPropertyNames:(NSMutableArray *)oPropertyNames
           propertyTypes:(NSMutableArray *) oPropertyTypes
           containParent:(BOOL)containParent;


- (BOOL)isSafeString;
- (BOOL)isSafeArray;
- (BOOL)isSafeDic;


//self is NSArray or NSDictionary instance(isValidJSONObject)
- (NSData *)jsonData;
//self is NSArray or NSDictionary instance(isValidJSONObject)
- (NSString*)jsonString;
//self is NSString or NSData instance(json stirng or json data)
//return value is NSArray or NSDictionary instance
- (id)objectFromJsonValue;

+ (NSMutableString *)whereQueryForInputValue:(id)where
                           outputColumnValues:(NSMutableArray *)values;

+ (NSMutableString *)queryStringForColumns:(id)columns
                                     table:(NSString*)tableName
                                     where:(id)where
                                   groupBy:(NSString *)groupBy
                                   orderBy:(NSString *)orderBy
                                     limit:(int)limit
                                    offset:(int)offset
                        outputColumnValues:(NSMutableArray *)values;


//convert db value to model value
+ (id)modelValueFromDBValue:(id)dbValue withPropertyToColumnMapping:(PropertyToColumnMapping *)mapping;

//convert model value to db value
+ (id)dbValueFromModel:(id)model withPropertyToColumnMapping:(PropertyToColumnMapping *)mapping;
+ (id)dbValueFromPropertyValue:(id)objcValue withPropertyToColumnMapping:(PropertyToColumnMapping *)mapping;


+(ModelToTableMapping*)modelToTableMapping;

@end



//=============
extern void setAssociatedObject(id obj,const void *key,id associatedObj);
extern id getAssociatedObject(id obj,const void *key);
extern void execAsyncBlock(void(^block)(void));
//convert model type to db type
extern NSString* dbTypeFromObjcType(NSString *objcType);
extern NSString* tableNameForClass(NSString *tableName,Class targetClass);
extern NSString* singleAutoIncrementPrimaryKeyForClass(Class targetClass);
extern id indicatorForModel(NSObject *model);
extern NSString* indicatorStringForModelWithOutputColumnValues(NSObject *model, NSMutableArray *outputColumnValues);
extern NSArray *propertiesToMapColumnsForClass(Class targetClass);




//=============
static NSString* const DBRowId = @"row_id";

static NSString* const DBTypeText        =   @"text";
static NSString* const DBTypeInt         =   @"integer";
static NSString* const DBTypeFloat       =   @"real";
static NSString* const DBTypeBlob        =   @"blob";

static NSString* const DBAttributeNotNull     =   @"NOT NULL";
static NSString* const DBAttributePrimaryKey  =   @"PRIMARY KEY";
static NSString* const DBAttributeDefault     =   @"DEFAULT";
static NSString* const DBAttributeUnique      =   @"UNIQUE";
static NSString* const DBAttributeCheck       =   @"CHECK";

static NSString* const DBConvertedFloat   =   @"float_double_decimal";
static NSString* const DBConvertedInt     =   @"int_char_short_long";
static NSString* const DBConvertedBlob     =   @"";






