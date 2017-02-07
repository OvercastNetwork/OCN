// -----------------------
// ---- Configuration ----
// -----------------------

var second_duration   = 1000;
var minute_duration   = 60 * second_duration;
var hour_duration     = 60 * minute_duration;
var day_duration      = 24 * hour_duration;
var week_duration     = 7  * day_duration;
var eternity_duration = new Date().getTime();

var profiles = {
	"day": day_duration,
	"week": week_duration,
	"eternity": eternity_duration,
};

// ---------------------------
// ---- Utility Functions ----
// ---------------------------

_ = {
// merge the given arguments into an array
merge: function(vargs) {
	var result = {};
	for (var i = 0; i < arguments.length; i++) {
		var obj = arguments[i];
		for (var key in obj) {
			result[key] = obj[key];
		}
	}
	return result;
},
// identity function - used in identity transformation example
id: function(obj) {
	return obj;
},
// invert numbers, arrays, or objects
inverse: function(obj) {
	switch (Object.prototype.toString.call(obj)) {
	case "[object Number]":
		return -obj;

	case "[object Array]":
		return obj.map(_.inverse);

	case "[object Object]":
		var result = {};
		for (var key in obj) {
			result[key] = _.inverse(obj[key]);
		}
		return result;

	default:
		return obj;
	}
},
sum: function(field, base, vargs) {
	var result = base[field] || 0;
	for(var i = 2; i < arguments.length; i++) {
		result += arguments[i][field] || 0;
	}
	base[field] = result;
},
greatest: function(field, def, base, vargs) {
	var result = base[field] || def;
	for(var i = 3; i < arguments.length; i++) {
		var x = arguments[i][field];
		if(x && x > result) {
			result = x;
		}
	}
	base[field] = result;
},
// determine the unique elements of an array
uniq: function(array) {
	var hash = {};
	var result = [];
	var array = array || result;
	for (var i = 0, l = array.length; i < l; ++i){
		if(hash.hasOwnProperty(array[i])) continue;
		result.push(array[i]);
		hash[array[i]] = 1;
	}
	return result;
},
// concat several objects
concat: function(field, vargs) {
	var result = [];
	for (var i = 1; i < arguments.length; i++) {
		var x = arguments[i][field];
		result.concat(x);
	}
	return result;
},
// determine if a value is meaningless (empty, null, 0, infinite date)
meaningless: function(obj) {
	if (obj == null) return true;
	if (obj == 0) return true;
	if (isNaN(obj)) return true;
	if (obj instanceof Date) return obj.getTime() == 0;
	if (obj instanceof Object && Object.keys(obj).length == 0) return true;

	return false;
},
// calculate kd, kk, and tk ratios given a stats object
calculate_kd: function(obj) {
	obj.kd     = (obj.kills      || 0) / (obj.deaths        || 1);
	obj.kk     = (obj.kills      || 0) / (obj.deaths_player || 1);
	obj.tkrate = (obj.kills_team || 0) / (obj.kills         || 1);
},
};

// --------------------------------
// ---- Generic Implementation ----
// --------------------------------
//

/*
 * Map, Reduce, and Finalize can all use variables defined in the map reduce scope.
 *
 * The variables included in the scope and their descriptions are listed below.
 *
 * _        - collection of utility functions
 * profile  - time period being map reduced
 * map      - map function for the specific collection
 * reduce   - reduce function for the specific collection
 * finalize - finalize function for the specific collection, can be null
 * key      - string that specifies which field has the date object
 *
 */

stats_map = function() {
	// get the implementation object
	var map_result = map.call(this);

	// store the date and family
	var date = map_result.date;
	var family = map_result.family;

	for (var emit_key in map_result.emit) {
		var emit_obj = map_result.emit[emit_key];

		transformations.forEach(function(transform) {
			if (transform.start <= date && date < transform.end) {
				emit_obj = transform.fn(emit_obj);
			}
		});

		var emit_result = {};
		emit_result[profile] = {};
		emit_result[profile]["global"] = {};
		emit_result[profile][family] = emit_obj;

		emit(emit_key, emit_result);
	}
}

stats_reduce = function(key, values) {
	var result = {};

	values.forEach(function(value) {
		for(var profile in value) {
			result[profile] = result[profile] || {};
			result[profile]["global"] = {};

			for(var family in value[profile]) {
				var family_result = result[profile][family] || {};
				var obj = value[profile][family];

				reduce(key, family_result, obj);

				for (var key in obj) {
					if (family_result[key] === undefined && obj[key] !== undefined) {
						family_result[key] = obj[key];
					}
				}

				result[profile][family] = family_result;
			}
		}
	});

	return result;
}

stats_finalize = function(key, value) {
	var totals = {
		playing_time               : {result: 0, type: "total"},
		deaths                     : {result: 0, type: "total"},
		deaths_player              : {result: 0, type: "total"},
		deaths_team                : {result: 0, type: "total"},
		kills                      : {result: 0, type: "total"},
		kills_team                 : {result: 0, type: "total"},
		wool_placed                : {result: 0, type: "total"},
		cores_leaked               : {result: 0, type: "total"},
		destroyables_destroyed     : {result: 0, type: "total"},
		last_death                 : {result: new Date(0), type: "recent"},
		last_kill                  : {result: new Date(0), type: "recent"},
		last_wool_placed           : {result: new Date(0), type: "recent"},
		last_core_leaked           : {result: new Date(0), type: "recent"},
		last_destroyable_destroyed : {result: new Date(0), type: "recent"},
	};

	// call finalize function (can be null)
	if (finalize) {
		for (var profile in value) {
			for (var family in value[profile]) {
				finalize(key, value[profile][family]);
			}
		}
	}

	for (var stat in totals) {
		for (var profile in value) {
			for (var family in value[profile]) {
				if(family == "global") continue;

				if(_.meaningless(value[profile][family][stat])) {
					delete value[profile][family][stat];
					continue;
				}

				switch (totals[stat].type) {
				case "total":
					totals[stat].result += (value[profile][family][stat] || 0);
					break;
				case "recent":
					if(value[profile][family][stat] > (totals[stat].result || new Date(0))) {
						totals[stat].result = value[profile][family][stat];
					}
					break;
				}
			}
		}

		totals[stat] = totals[stat].result;

		if(_.meaningless(totals[stat])) delete totals[stat];
	}

	_.calculate_kd(totals);

	value[profile]["global"] = totals;

	return value;
}

var stats = {}; // records how to mapreduce on certain collections

// -------------------------------
// ---- Deaths Implementation ----
// -------------------------------

deaths_map = function() {
	var family = this.family || "default";

	var victim = {last_death: this.date};
	var killer = {};

	if (this.teamkill) {
		victim.deaths_team = 1;
		if (this.killer) killer.kills_team = 1;
	} else {
		victim.deaths = 1;
		if (this.killer) {
			victim.deaths_player = 1;
			killer.kills = 1;
			killer.last_kill = this.date;
		}
	}

	var emit = {};
	emit[this.victim] = victim;
	if (this.killer) emit[this.killer] = killer;

	return { "date": this.date, "family": family, "emit": emit };
}

deaths_reduce = function(key, result, obj) {
	["deaths", "deaths_player", "deaths_team", "kills", "kills_team"].forEach(function(field) {
		_.sum(field, result, obj);
	});

	["last_death", "last_kill"].forEach(function(field) {
		_.greatest(field, new Date(0), result, obj);
	});
}

deaths_finalize = function(key, value) {
	_.calculate_kd(value);
	return value;
}

stats["deaths"] = {
	map: deaths_map,
	reduce: deaths_reduce,
	finalize: deaths_finalize,
	key: "date",
	query: {
		date: {$exists: 1},
		victim: {$exists: 1}
	},
	db: "oc_deaths",
};

// ---------------------------------------
// ---- Participations Implementation ----
// ---------------------------------------

participations_map = function() {
	var emit = {};

	var family = this.family || "default";
	var duration = this.end.getTime() - this.start.getTime();

	// 'team_id' is the current field, 'team' is only on legacy documents
	if (this.team_id || (this.team && this.team != "Observers" && this.team != "Spectators")) {
		emit["playing_time"] = duration;
	}

	var emit_result = {};
	emit_result[this.player] = emit;

	return { date: this.end, family: family, emit: emit_result };
}

participations_reduce = function(key, result, obj) {
	["playing_time"].forEach(function(field) {
		_.sum(field, result, obj);
	});
}

stats["participations"] = {
	map: participations_map,
	reduce: participations_reduce,
	key: "end",
	query: {
		start: {$exists: 1},
		end: {$exists: 1},
		player: {$exists: 1},
	},
	db: "oc_participations",
};

// -----------------------------------
// ---- Objectives Implementation ----
// -----------------------------------

objectives_map = function() {
	var emit = {};

	var family = this.family || "default";

	switch (this.type) {
	case "wool_place":
		emit["wool_placed"] = 1;
		emit["last_wool_placed"] = this.date;
		break;
	case "destroyable_destroy":
		emit["destroyables_destroyed"] = 1;
		emit["last_destroyable_destroyed"] = this.date;
		break;
	case "core_break":
		emit["cores_leaked"] = 1;
		emit["last_core_leaked"] = this.date;
		break;
	}

	var emit_result = {};
	emit_result[this.player] = emit;

	return { date: this.date, family: family, emit: emit_result };
}

objectives_reduce = function(key, result, obj) {
	["wool_placed", "destroyables_destroyed", "cores_leaked"].forEach(function(field) {
		_.sum(field, result, obj);
	});

	["last_wool_placed", "last_destroyable_destroyed", "last_core_leaked"].forEach(function(field) {
		_.greatest(field, new Date(0), result, obj);
	});
}

stats["objectives"] = {
	map: objectives_map,
	reduce: objectives_reduce,
	key: "date",
	query: {
		date: {$exists: 1},
		player: {$exists: 1},
	},
	db: "oc_objectives",
};

// ----------------------------------
// ---- Execution Implementation ----
// ----------------------------------

/*
 * We subtract 1 minute from the current time to help deal with improper statistics.
 *
 * Improper statistics happen because the timestamp is generated on the client side
 * and there can be anywhere from a millisecond to a multiple second delay on insertion.
 *
 * This bug originally caused negative statistics because the death/objective/playing time
 * statistic wasn't credited to the player but was later subtracted.
 *
 * Sliding our time frame window lets us catch some of these delayed statistics and
 * massively decrease the number of improper statistics. Using server-side timestamps
 * would fix the problem, but, we would rather have timestamps match the game.
 */
var now = new Date(new Date().getTime() - (1 * minute_duration));

var upsert = {};

for (var profile in profiles) {
	upsert["last_run." + profile] = now;
}

var jobsDB = db.getSiblingDB("oc_jobs");
var j = jobsDB.jobs.findAndModify({
	query: {name: "player_stats"},
	update: {$set: upsert},
	upsert: true
});

var scope_base = { "_": _ };

for (var profile in profiles) {
	// calculate when the profile was last run
	var last_run = (j && j.last_run && j.last_run[profile]) || new Date(0);

	print("Profile '" + profile + "' last run at " + last_run);

	var duration = profiles[profile];

	// calculate the add / re
	var add_start = last_run;
	var add_end = now;
	var sub_start = new Date(Math.max(0, add_start.getTime() - duration));
	var sub_end = new Date(Math.max(0, add_end.getTime() - duration));

	// sub: |-----------|
	// add:		|--------------|
	//
	// sub: |------|
	// add:			 |---------|
	if (add_start < sub_end) {
		var old_end = sub_end;
		sub_end = add_start;
		add_start = old_end;
	}

	// describes what function needs to apply to a selected range
	// the commented out identity transformation exists for educational purposes
	var transformations = [
		/*
		{
			start: add_start,
			end: add_end,
			fn: _.id,
		},
		*/
		{
			start: sub_start,
			end: sub_end,
			fn: _.inverse,
		},
	];

	var scope_profile = _.merge(scope_base, {
		profile: profile,
		transformations: transformations,
	});

	var total_result = {
		result: "oc_player_stats_" + profile,
		timeMillis: 0,
		counts: {
			input:  0,
			emit:   0,
			reduce: 0,
			output: 0,
		},
	};

	for (var collection in stats) {
		print("Processing collection: " + collection);

		var info = stats[collection];

		// local variables accessible by the map, reduce, and finalize functions
		var scope = _.merge(scope_profile, {
			key: info.key,
			map: info.map,
			reduce: info.reduce,
			finalize: info.finalize,
		});

		var add_range = {};
		add_range[info.key] = {$gte: add_start, $lt: add_end};

		var sub_range = {};
		sub_range[info.key] = {$gte: sub_start, $lt: sub_end};

		var query = _.merge(info.query || {}, {
			$or: [ add_range, sub_range ]
		});

		// do mapreduce
		var options = {
			out: {reduce: "player_stats_" + profile, db: "oc_playerstats"},
			scope: scope,
			query: query,
			finalize: stats_finalize,
		};

		var database = db.getSiblingDB(info.db);
		var result = database[collection].mapReduce(stats_map, stats_reduce, options);

		printjson(result);

		if (result.ok) {
			total_result.timeMillis += result.timeMillis;
			total_result.counts.input += result.counts.input;
			total_result.counts.emit += result.counts.emit;
			total_result.counts.reduce += result.counts.reduce;
			total_result.counts.output += result.counts.output;
		}
	}

	print("Results for '" + profile + "' profile")
	printjson(total_result);
}

