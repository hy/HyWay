# This Makefile assumes mongo access params are in local ENV
#   under both ENV var conventions, new + old

MAIN = TheApp.rb Gemfile Gemfile.lock Makefile
VIEWS = views/list.erb static/main.css

SERVER = http://serene-forest-4377.herokuapp.com/

MONGOPATH = ~/mongodb-osx-x86_64-2.6.1/bin
MONGO_RSET_URL = lighthouse.0.mongolayer.com:10104/production

DB = latest

AUDIO = ~/Dropbox/HyWay/static/VascularContent/Audio
IMAGES = ~/Dropbox/HyWay/static/VascularContent/Images
VIDEO = ~/Dropbox/HyWay/static/VascularContent/Video
METADATA = ~/Dropbox/HyWay/static/VascularContent/metadata.json
CONTENT_MSG = "TRY: Commit a Content / Metadata update"


###################### Begin Generic git Interactions #####################

known:
	clear
	git status

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


##################### Begin Aux/Mongo Interactions ###################

# http://www.gitguys.com/how-to-remove-a-file-from-git-source-control-but-not-delete-it/


m-rset-shell:
	$(MONGOPATH)/mongo lighthouse.0.mongolayer.com:10104/production -u $(MONGO_USER_ID) -p $(MONGO_PASSWORD)

m-primary-election:
	
m-oplog_dump:
	

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
	git commit -m TRY:'$(m)'
	git push -u heroku master

go:
	heroku open

checkpoint:
	git add Makefile $(MAIN) $(VIEWS) Gemfile Gemfile.lock
	git commit -m WORKS:'$(m)'
	git push -u github master
	git push -u heroku master
	curl -G -v  $(SERVER)log_at_asana --data-urlencode "m=$(m)"



##################### App-Specific Import / Exports #####################

import_tracking:
	~/Downloads/flip.universal -u ~/Documents/NooraTracking.csv
#	tail -n +2 ~/Documents/NooraTracking.csv > ~/Documents/NooraTrackingReady.csv
	$(MONGOPATH)/mongoimport --host $(MONGO_URL) -port $(MONGO_PORT) -d $(DB) -c noora_tracking -u $(MONGO_USER_ID) -p $(MONGO_PASSWORD) --type csv --file ~/Documents/NooraTrackingReady.csv --headerline

import_test:
	$(MONGOPATH)/mongoimport --host $(MONGO_URL) -port $(MONGO_PORT) -d $(DB) -c noora_tracking -u $(MONGO_USER_ID) -p $(MONGO_PASSWORD) --type csv --file ~/Documents/TestCCs.csv --headerline

import_daily_feed:
	~/Downloads/flip.universal -u ~/Documents/Inpatients_0724.csv
	tail -n +9 ~/Documents/Inpatients_0724.csv > ~/Documents/InpatientSampleReady.csv
	$(MONGOPATH)/mongoimport --host $(MONGO_URL) -port $(MONGO_PORT) -d $(DB) -c inpatients -u $(MONGO_USER_ID) -p $(MONGO_PASSWORD) --type csv --file ~/Documents/InpatientSampleReady.csv --headerline

import_links:
	~/Downloads/flip.universal -u ~/Documents/Links.csv
	$(MONGOPATH)/mongoimport --host $(MONGO_URL) -port $(MONGO_PORT) -d $(DB) -c links -u $(MONGO_USER_ID) -p $(MONGO_PASSWORD) --type csv --file ~/Documents/Links.csv --headerline

import_bangalore:
	~/Downloads/flip.universal -u ~/Documents/bangalore.csv
	$(MONGOPATH)/mongoimport --host $(MONGO_URL) -port $(MONGO_PORT) -d $(DB) -c bangalore -u $(MONGO_USER_ID) -p $(MONGO_PASSWORD) --type csv --file ~/Documents/bangalore.csv --headerline

import_testers:
	~/Downloads/flip.universal -u ~/Documents/Testers.csv
	$(MONGOPATH)/mongoimport --host $(MONGO_URL) -port $(MONGO_PORT) -d $(DB) -c bangalore -u $(MONGO_USER_ID) -p $(MONGO_PASSWORD) --type csv --file ~/Documents/Testers.csv --headerline

export_tracking:
	$(MONGOPATH)/mongoexport --host $(MONGO_URL) -port $(MONGO_PORT) -d $(DB) -c noora_tracking -u $(MONGO_USER_ID) -p $(MONGO_PASSWORD) --out ~/Documents/NooraTrackingDump.json

replicate_tracking:
        $(MONGOPATH)/mongoimport --host $(MONGO_RSET_URL) -port $(MONGO_RSET_PORT) -d $(DB) -c noora_tracking -u $(MONGO_RSET_USER_ID) -p $(MONGO_RSET_PASSWORD) --file ~/Documents/NooraTrackingDump.json


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

