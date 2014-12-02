
# This Makefile assumes mongo access params are in local ENV
#   under both ENV var conventions, new + old

MAIN = TheApp.rb Gemfile Gemfile.lock Makefile
VIEWS = views/list.erb static/main.css

SERVER = http://serene-forest-4377.herokuapp.com/

MONGOPATH = ~/mongodb-osx-x86_64-2.6.1/bin
REDISPATH = ~/redis-2.8.17/src/

DB = $(MONGO_DB_NAME) 

AUDIO = ~/Dropbox/HyWay/static/VascularContent/Audio
IMAGES = ~/Dropbox/HyWay/static/VascularContent/Images
VIDEO = ~/Dropbox/HyWay/static/VascularContent/Video
METADATA = ~/Dropbox/HyWay/static/VascularContent/metadata.json
CONTENT_MSG = "TRY: Commit a Content / Metadata update"


###################### Begin Generic git Interactions #####################

known:
	clear
	git status

github:
	push -u github master

aware:
	heroku logs -t

a:
	echo $(CONTENT_MSG)
	/bin/date

g-diff:
	clear
	git diff $(MAIN)

g-rollback:
	git reset --soft HEAD~1


monitor:
	heroku logs -t


##################### Begin Aux/Mongo Interactions ###################

# http://www.gitguys.com/how-to-remove-a-file-from-git-source-control-but-not-delete-it/



r-shell:
	$(REDISPATH)/redis-cli -h $(REDIS_HOST) -p $(REDIS_PORT) -a $(REDIS_A) 

m-rset-shell:
	$(MONGOPATH)/mongo lighthouse.0.mongolayer.com:10104/production -u $(MONGO_USER_ID) -p $(MONGO_PASSWORD)

m-primary-election:
	
m-oplog_dump:

old-m-shell:
	$(MONGOPATH)/mongo dharma.mongohq.com:10070/latest -u $(MONGO_USER_ID) -p $(MONGO_PASSWORD)	

m-shell:
	$(MONGOPATH)/mongo $(MONGO_URL):$(MONGO_PORT)/$(DB) -u $(MONGO_USER_ID) -p $(MONGO_PASSWORD)

a-task:
	curl -G -v  $(SERVER)log_at_asana --data-urlencode "m=$(m)"


##################### Begin Fundamental/Basic Interactions ###################

gems:
	bundle update
	git add Gemfile Gemfile.lock
	git commit -m "UPDATE: Gems"
	git push -u heroku master

it:
	git add Makefile $(MAIN) $(VIEWS)
	git commit -m '$(m)'
	git push -u heroku master

go:
	heroku open

checkpoint:
	git add Makefile $(MAIN) $(VIEWS) Gemfile Gemfile.lock
	git commit -m WORKS:'$(m)'
	git push -u github master
	git push -u heroku master

asana:
	curl -G -v  $(SERVER)log_at_asana --data-urlencode "m=$(m)"



##################### App-Specific Import / Exports #####################

import_of_tracking:
	~/Downloads/flip.universal -u ~/Documents/NooraTracking.csv
#	tail -n +2 ~/Documents/NooraTracking.csv > ~/Documents/NooraTrackingReady.csv
	$(MONGOPATH)/mongoimport --host $(MONGO_URL) -port $(MONGO_PORT) -d $(DB) -c noora_tracking -u $(MONGO_USER_ID) -p $(MONGO_PASSWORD) --type csv --file ~/Documents/NooraTrackingReady.csv --headerline

import_test:
	$(MONGOPATH)/mongoimport --host $(MONGO_URL) -port $(MONGO_PORT) -d $(DB) -c noora_tracking -u $(MONGO_USER_ID) -p $(MONGO_PASSWORD) --type csv --file ~/Documents/TestCCs.csv --headerline

import_of_daily_feed:
	~/Downloads/flip.universal -u ~/Documents/Inpatients_0724.csv
	tail -n +9 ~/Documents/Inpatients_0724.csv > ~/Documents/InpatientSampleReady.csv
	$(MONGOPATH)/mongoimport --host $(MONGO_URL) -port $(MONGO_PORT) -d $(DB) -c inpatients -u $(MONGO_USER_ID) -p $(MONGO_PASSWORD) --type csv --file ~/Documents/InpatientSampleReady.csv --headerline

import_of_links:
	~/Downloads/flip.universal -u ~/Documents/Links.csv
	$(MONGOPATH)/mongoimport --host $(MONGO_URL) -port $(MONGO_PORT) -d $(DB) -c links -u $(MONGO_USER_ID) -p $(MONGO_PASSWORD) --type csv --file ~/Documents/Links.csv --headerline

import_of_bangalore:
	~/Downloads/flip.universal -u ~/Documents/bangalore.csv
	$(MONGOPATH)/mongoimport --host $(MONGO_URL) -port $(MONGO_PORT) -d $(DB) -c bangalore -u $(MONGO_USER_ID) -p $(MONGO_PASSWORD) --type csv --file ~/Documents/bangalore.csv --headerline

import_of_sample_csv:
	~/Downloads/flip.universal -u ~/Documents/Admission_and_Discharge_Report.csv
	$(MONGOPATH)/mongoimport --host $(MONGO_URL) -port $(MONGO_PORT) -d $(DB) -c sample_csv -u $(MONGO_USER_ID) -p $(MONGO_PASSWORD) --type csv --file ~/Documents/Admission_and_Discharge_Report.csv --headerline

import_of_kolkata:
	~/Downloads/flip.universal -u ~/Documents/kolkata.csv
	tail -n +16 ~/Documents/kolkata.csv > ~/Documents/k.csv
	$(MONGOPATH)/mongoimport --host $(MONGO_URL) -port $(MONGO_PORT) -d $(DB) -c kolkata -u $(MONGO_USER_ID) -p $(MONGO_PASSWORD) --type csv --file ~/Documents/k.csv --headerline --ignoreBlanks

import_of_sms_content:
	~/Downloads/flip.universal -u ~/Documents/sms_content.csv
	$(MONGOPATH)/mongoimport --host $(MONGO_URL) -port $(MONGO_PORT) -d $(DB) -c sms_content -u $(MONGO_USER_ID) -p $(MONGO_PASSWORD) --type csv --file ~/Documents/sms_content.csv --headerline

import_of_testers:
	~/Downloads/flip.universal -u ~/Documents/Testers.csv
	$(MONGOPATH)/mongoimport --host $(MONGO_URL) -port $(MONGO_PORT) -d $(DB) -c bangalore -u $(MONGO_USER_ID) -p $(MONGO_PASSWORD) --type csv --file ~/Documents/Testers.csv --headerline

import_of_liberia:
	~/Downloads/flip.universal -u ~/Documents/liberia100.csv
	$(MONGOPATH)/mongoimport --host $(MONGO_URL) -port $(MONGO_PORT) -d $(DB) -c liberia -u $(MONGO_USER_ID) -p $(MONGO_PASSWORD) --type csv --file ~/Documents/liberia100.csv --headerline

export_of_liberia:
	$(MONGOPATH)/mongoexport --host $(MONGO_URL) -port $(MONGO_PORT) -d $(DB) -c liberia -u $(MONGO_USER_ID) -p $(MONGO_PASSWORD) --csv --out ~/Documents/LibCalls.csv --fields 'Phone Number',A1,A2,A3,CallStatus,CallDuration





export_of_tracking:
	$(MONGOPATH)/mongoexport --host $(MONGO_URL) -port $(MONGO_PORT) -d $(DB) -c noora_tracking -u $(MONGO_USER_ID) -p $(MONGO_PASSWORD) --out ~/Documents/NooraTrackingDump.json

export_of_bangalore:
	$(MONGOPATH)/mongoexport --host $(MONGO_URL) -port $(MONGO_PORT) -d $(DB) -c bangalore -u $(MONGO_USER_ID) -p $(MONGO_PASSWORD) --out ~/Documents/BangaloreDump.json

export_of_calls_made:
	$(MONGOPATH)/mongoexport --host $(MONGO_URL) -port $(MONGO_PORT) -d $(DB) -c calls -u $(MONGO_USER_ID) -p $(MONGO_PASSWORD) --out ~/Documents/CallLogDump.json


###################### App specific Route Triggers ############################

reminder_calls:
	curl http://serene-forest-4377.herokuapp.com/make_reminder_calls

content_updates: $(AUDIO) $(IMAGES) $(VIDEO)
	git add --all $(AUDIO) $(IMAGES) $(VIDEO)
	date >> content_updates
	git commit -m $(CONTENT_MSG)
	git push -u heroku master 
	echo $(CONTENT_MSG) >> ./ACTIVE_COMMIT

meta: $(METADATA)
	git add $(METADATA)
	git commit -m "TRY: Metadata update"
	git push -u heroku master

metarefresh:
	curl http://carecompanion.noorahealth.org/restockmongo


# make ready
# make whole
# make it so

