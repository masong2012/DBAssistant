//
//  DBAssistant.h
//  Database
//
//  Created by MaSong on 15/8/20.
//  Copyright (c) 2015年 MaSong. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FMDatabase.h"
#import "FMDatabaseQueue.h"
#import "DBHelpers.h"
#import "DBMappings.h"

@interface DBAssistant : NSObject

- (DBAssistant *)initWithDBPath:(NSString*)filePath;

- (void)setDBPath:(NSString*)filePath;

- (void)beginTransaction;
- (void)commit;
- (void)rollback;

- (void)executeDB:(void (^)(FMDatabase *db))block;

- (BOOL)executeUpdate:(NSString *)updateSql withArguments:(NSArray *)args;


- (BOOL)createTable:(NSString*)tableName forClass:(Class)targetClas;
- (BOOL)createTableForClass:(Class)targetClas ;

- (void)dropAllTables;
- (BOOL)dropTableForClass:(Class)targetClas;


- (id)firstModelFromTable:(NSString *)tableName where:(NSObject *)where forClass:(Class)targetClass;
- (id)firstModelFromTable:(NSString *)tableName where:(NSObject *)where orderBy:(NSString*)orderBy forClass:(Class)targetClass;

- (id)lastModelFromTable:(NSString *)tableName  forClass:(Class)targetClass;

- (NSArray *)allModelsFromTable:(NSString *)tableName forClass:(Class)targetClass;


- (NSArray *)selectModelsFromTable:(NSString *)tableName where:(NSObject *)where forClass:(Class)targetClass;
- (NSArray *)selectModelsFromTable:(NSString *)tableName where:(id)where groupBy:(NSString *)groupBy orderBy:(NSString*)orderBy limit:(int)limit offset:(int)offset forClass:(Class)targetClass;



- (BOOL)insertModel:(NSObject *)model intoTable:(NSString *)tableName forClass:(Class)targetClass;
- (BOOL)insertModelIfNotExists:(NSObject *)model intoTable:(NSString *)tableName forClass:(Class)targetClass;



- (BOOL)deleteModel:(NSObject *)model fromTable:(NSString *)tableName forClass:(Class)targetClass;
- (BOOL)deleteModelsFromTable:(NSString *)tableName where:(id)where forClass:(Class)targetClass;


- (BOOL)updateTable:(NSString *)tableName withKeysAndValues:(NSDictionary *)keysAndValues where:(id)where forClass:(Class)targetClass;
- (BOOL)updateTable:(NSString *)tableName withModel:(NSObject *)model where:(id)where forClass:(Class)targetClass;



- (BOOL)modelExists:(NSObject *)model inTable:(NSString *)tableName forClass:(Class)targetClass;

- (NSInteger)rowCountOfTableName:(NSString*)tableName where:(id)where forClass:(Class)targetClass;

- (NSMutableArray *)progressResultSet:(FMResultSet *)set forTable:(NSString*)tableName targetClass:(Class)targetClass ;
@end





