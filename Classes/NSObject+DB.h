//
//  NSObject+DB.h
//  Baitu
//
//  Created by MaSong on 2016/12/17.
//  Copyright © 2016年 MaSong. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DBAssistant.h"

@interface NSObject (DB)

@property (assign,nonatomic) NSUInteger row_id;
@property (strong,nonatomic) NSString *table_name;

//dbPath
+(NSString*)dbPath;

//tableName
+(NSString*)tableName;

//primarykeys
+(NSArray*)primaryKeys;

//only properties to map table columns
+(NSArray *)onlyPropertiesToMapColumns;

//except properties to map table columns
+(NSArray *)exceptPropertiesToMapColumns;

//property to  column Mappings
+(NSDictionary *)propertyToColumnMappings;

//properties default values
+(NSDictionary *)defaultValues;

//properties value check values
+(NSDictionary *)checkValues;

//properties value length
+(NSDictionary *)lengthValues;

//properties value those should be unique
+(NSArray *)uniqueValues;

//properties value those should be not null
+(NSArray *)notNullValues;

+(NSString *)dateFormatterString;
+(NSString *)imagePathForImage:(NSString *)imgName ;
+(NSString *)dataPathForData:(NSString *)dataName;

//default is YES
+(BOOL)shouldMapAllParentPropertiesToTable;
//default is YES
+(BOOL)shouldMapAllSelfPropertiesToTable;


+(BOOL)createTable;
+(BOOL)dropTable;


+(BOOL)insertModel:(NSObject *)model;
+(BOOL)insertModelIfNotExists:(NSObject *)model;


+(BOOL)deleteModel:(NSObject *)model;
+(BOOL)deleteModelsWhere:(NSObject *)where;


+(BOOL)updateModelsWithModel:(NSObject *)model where:(NSObject *)where;
+(BOOL)updateModelsWithDictionary:(NSDictionary *)dic where:(NSObject *)where;


+(BOOL)modelExists:(NSObject *)model;

+(NSArray *)allModels;

+(NSArray *)findModelsBySQL:(NSString *)sql;
+(NSArray *)findModelsWhere:(NSObject *)where;
+(NSArray *)findModelsWhere:(NSObject *)where orderBy:(NSString *)orderBy;
+(NSArray *)findModelsWhere:(NSObject *)where groupBy:(NSString *)groupBy orderBy:(NSString*)orderBy limit:(int)limit offset:(int)offset;

+(id)firstModelWhere:(NSObject *)where;
+(id)firstModelWhere:(NSObject *)where orderBy:(NSString*)orderBy ;

+(id)lastModel;

+ (NSInteger)rowCountWhere:(NSObject *)where;

- (BOOL)saveModel;
- (BOOL)deleteModel;
- (BOOL)updateModel:(id)value;


+(void)beginTransaction;
+(void)commit;
+(void)rollback;

+(DBAssistant *)currentDBAssistant;

@end


