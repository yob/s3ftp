# s3ftp

A mini-FTP server that persists all data to Amazon S3.

## Installation

    gem install s3ftp

## Configuration

1. Upload a passwd file to your S3 bucket. It should contain a single line
   per user and be a CSV. It should look something like this

   user1,password,y
   user2,password,n

   the third column indicates the users administrator status. Administrators can
   see all files. Regular users are sandboxed to their own directory.

2. Create a config.rb file that looks something like this

    require 's3ftp'

    AWS_KEY    = 'foo'
    AWS_SECRET = 'bar'
    AWS_BUCKET = 'my-ftp-bucket'

    driver      S3FTP::Driver
    driver_args AWS_KEY, AWS_SECRET, AWS_BUCKET

3. As root, run 'em-ftpd config.rb'

## License

This library is distributed under the terms of the MIT License. See the included file for
more detail.
