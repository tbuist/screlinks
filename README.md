# screlinks

Scrapes reddit.com/r/megalinks/new every minute for matching posts

### Features
* Matches titles with regexps
* Hits Trakt.tv API for TV Show Collection
* Miscellaneous searches by adding filenames to command arguments
* Pushbullet notication upon match

### Usage
```ruby main.rb $PUSHAPI_KEY $TRAKTAPI_KEY [searchlist1.txt] [searchlist2.txt]```

### Help
* Get your Pushbullet API Access Token [here](https://www.pushbullet.com/#settings/account)
* Get your Trakt.tv API key by creating a new app [here](https://trakt.tv/oauth/applications)
