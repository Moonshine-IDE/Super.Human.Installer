#!/bin/bash
mysql -u root $1 -e 'DROP INDEX idx_posts_message_txt ON Posts'
mysql -u root $1 -e 'CREATE FULLTEXT INDEX idx_posts_message_txt ON Posts (Message) WITH PARSER ngram'
mysql -u root $1 -e 'DROP INDEX idx_posts_hashtags_txt ON Posts'
mysql -u root $1 -e 'CREATE FULLTEXT INDEX idx_posts_hashtags_txt ON Posts (Hashtags) WITH PARSER ngram'
