package com.skytrace.repo

import androidx.room.Dao
import androidx.room.Database
import androidx.room.Delete
import androidx.room.Entity
import androidx.room.Index
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.PrimaryKey
import androidx.room.Query
import androidx.room.RawQuery
import androidx.room.RoomDatabase
import androidx.room.Update
import androidx.sqlite.db.SupportSQLiteQuery
import kotlinx.serialization.Serializable

@Entity(
    tableName = "traffic",
    indices = [Index("timestamp"), Index("host"), Index("appPackage"), Index("method"), Index("statusCode")]
)
class TrafficEntity(
    @PrimaryKey(autoGenerate = true) var id: Long = 0,
    var timestamp: Long = 0,
    var method: String = "",
    var scheme: String = "",
    var host: String = "",
    var port: Int = 0,
    var path: String = "",
    var url: String = "",
    var httpVersion: String = "",
    var statusCode: Int = 0,
    var statusMessage: String = "",
    var requestHeaders: String = "[]",
    var responseHeaders: String = "[]",
    var requestBody: ByteArray? = null,
    var responseBody: ByteArray? = null,
    var requestSize: Long = 0,
    var responseSize: Long = 0,
    var requestContentType: String = "",
    var responseContentType: String = "",
    var requestTruncated: Boolean = false,
    var responseTruncated: Boolean = false,
    var appPackage: String = "",
    var appName: String = "",
    var uid: Int = -1,
    var remoteIp: String = "",
    var connectMs: Long = 0,
    var tlsMs: Long = 0,
    var sendMs: Long = 0,
    var waitMs: Long = 0,
    var receiveMs: Long = 0,
    var totalMs: Long = 0,
    var error: String? = null,
    var isWebSocket: Boolean = false,
    var tunnel: Boolean = false,
    var modified: Boolean = false,
    var replayOf: Long = 0
)

@Serializable
class TrafficSummary(
    val id: Long,
    val timestamp: Long,
    val method: String,
    val scheme: String,
    val host: String,
    val path: String,
    val statusCode: Int,
    val responseSize: Long,
    val requestSize: Long,
    val contentType: String,
    val appPackage: String,
    val appName: String,
    val totalMs: Long,
    val modified: Boolean,
    val isWebSocket: Boolean,
    val tunnel: Boolean,
    val statusMessage: String,
    val error: String?
)

@Serializable
class AppFacet(val appPackage: String, val appName: String, val requests: Int)

@Serializable
class HostFacet(val host: String, val requests: Int)

@Serializable
class AppStat(val appPackage: String, val appName: String, val requests: Int, val up: Long, val down: Long, val avgMs: Double)

@Serializable
class DomainStat(val host: String, val requests: Int, val down: Long, val avgMs: Double)

@Serializable
class Totals(val requests: Int, val up: Long, val down: Long, val avgMs: Double)

@Serializable
class TimeBuckets(val b1: Int, val b2: Int, val b3: Int, val b4: Int, val b5: Int)

@Serializable
class StatusBuckets(val s1: Int, val s2: Int, val s3: Int, val s4: Int, val s5: Int, val s0: Int)

@Serializable
class SeriesPoint(val minute: Long, val count: Int)

@Entity(tableName = "rules")
class RuleEntity(
    @PrimaryKey(autoGenerate = true) var id: Long = 0,
    var json: String = "",
    var enabled: Boolean = true
)

@Entity(tableName = "breakpoints")
class BreakpointEntity(
    @PrimaryKey(autoGenerate = true) var id: Long = 0,
    var json: String = "",
    var enabled: Boolean = true
)

@Dao
interface TrafficDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(entity: TrafficEntity): Long

    @Update
    suspend fun update(entity: TrafficEntity)

    @Query("SELECT * FROM traffic WHERE id = :id LIMIT 1")
    suspend fun byId(id: Long): TrafficEntity?

    @Query("DELETE FROM traffic WHERE id IN (:ids)")
    suspend fun deleteIds(ids: List<Long>)

    @Query("DELETE FROM traffic")
    suspend fun deleteAll()

    @Query("SELECT COUNT(*) FROM traffic")
    suspend fun count(): Int

    @Query("DELETE FROM traffic WHERE id NOT IN (SELECT id FROM traffic ORDER BY id DESC LIMIT :keep)")
    suspend fun trim(keep: Int)

    @RawQuery
    suspend fun summaries(query: SupportSQLiteQuery): List<TrafficSummary>

    @RawQuery
    suspend fun entities(query: SupportSQLiteQuery): List<TrafficEntity>

    @RawQuery
    suspend fun countRaw(query: SupportSQLiteQuery): Int

    @Query("SELECT appPackage, appName, COUNT(*) AS requests FROM traffic GROUP BY appPackage ORDER BY requests DESC")
    suspend fun appFacets(): List<AppFacet>

    @Query("SELECT host, COUNT(*) AS requests FROM traffic GROUP BY host ORDER BY requests DESC LIMIT 60")
    suspend fun hostFacets(): List<HostFacet>

    @Query("SELECT COUNT(*) AS requests, COALESCE(SUM(requestSize),0) AS up, COALESCE(SUM(responseSize),0) AS down, COALESCE(AVG(CASE WHEN totalMs > 0 THEN totalMs END),0) AS avgMs FROM traffic")
    suspend fun totals(): Totals

    @Query("SELECT appPackage, appName, COUNT(*) AS requests, COALESCE(SUM(requestSize),0) AS up, COALESCE(SUM(responseSize),0) AS down, COALESCE(AVG(CASE WHEN totalMs > 0 THEN totalMs END),0) AS avgMs FROM traffic GROUP BY appPackage ORDER BY requests DESC LIMIT 12")
    suspend fun perApp(): List<AppStat>

    @Query("SELECT host, COUNT(*) AS requests, COALESCE(SUM(responseSize),0) AS down, COALESCE(AVG(CASE WHEN totalMs > 0 THEN totalMs END),0) AS avgMs FROM traffic GROUP BY host ORDER BY requests DESC LIMIT 10")
    suspend fun topDomains(): List<DomainStat>

    @Query("SELECT COALESCE(SUM(CASE WHEN totalMs < 100 THEN 1 ELSE 0 END),0) AS b1, COALESCE(SUM(CASE WHEN totalMs >= 100 AND totalMs < 300 THEN 1 ELSE 0 END),0) AS b2, COALESCE(SUM(CASE WHEN totalMs >= 300 AND totalMs < 1000 THEN 1 ELSE 0 END),0) AS b3, COALESCE(SUM(CASE WHEN totalMs >= 1000 AND totalMs < 3000 THEN 1 ELSE 0 END),0) AS b4, COALESCE(SUM(CASE WHEN totalMs >= 3000 THEN 1 ELSE 0 END),0) AS b5 FROM traffic WHERE totalMs > 0 AND tunnel = 0")
    suspend fun timeBuckets(): TimeBuckets

    @Query("SELECT COALESCE(SUM(CASE WHEN statusCode BETWEEN 100 AND 199 THEN 1 ELSE 0 END),0) AS s1, COALESCE(SUM(CASE WHEN statusCode BETWEEN 200 AND 299 THEN 1 ELSE 0 END),0) AS s2, COALESCE(SUM(CASE WHEN statusCode BETWEEN 300 AND 399 THEN 1 ELSE 0 END),0) AS s3, COALESCE(SUM(CASE WHEN statusCode BETWEEN 400 AND 499 THEN 1 ELSE 0 END),0) AS s4, COALESCE(SUM(CASE WHEN statusCode >= 500 THEN 1 ELSE 0 END),0) AS s5, COALESCE(SUM(CASE WHEN statusCode = 0 THEN 1 ELSE 0 END),0) AS s0 FROM traffic")
    suspend fun statusBuckets(): StatusBuckets

    @Query("SELECT (timestamp / 60000) AS minute, COUNT(*) AS count FROM traffic WHERE timestamp > :since GROUP BY minute ORDER BY minute")
    suspend fun series(since: Long): List<SeriesPoint>
}

@Dao
interface RuleDao {
    @Query("SELECT * FROM rules ORDER BY id ASC")
    suspend fun all(): List<RuleEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(entity: RuleEntity): Long

    @Query("DELETE FROM rules WHERE id = :id")
    suspend fun delete(id: Long)

    @Query("SELECT * FROM rules WHERE id = :id LIMIT 1")
    suspend fun byId(id: Long): RuleEntity?
}

@Dao
interface BreakpointDao {
    @Query("SELECT * FROM breakpoints ORDER BY id ASC")
    suspend fun all(): List<BreakpointEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(entity: BreakpointEntity): Long

    @Query("DELETE FROM breakpoints WHERE id = :id")
    suspend fun delete(id: Long)

    @Query("SELECT * FROM breakpoints WHERE id = :id LIMIT 1")
    suspend fun byId(id: Long): BreakpointEntity?
}

@Database(
    entities = [TrafficEntity::class, RuleEntity::class, BreakpointEntity::class],
    version = 1,
    exportSchema = false
)
abstract class SkyDatabase : RoomDatabase() {
    abstract fun trafficDao(): TrafficDao
    abstract fun ruleDao(): RuleDao
    abstract fun breakpointDao(): BreakpointDao
}
