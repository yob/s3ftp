# s3ftp

A mini-FTP server that persists all data to Amazon S3.

## Installation

    gem install s3ftp

## Configuration

1. Create a new, empty S3 bucket
2. As root, run s3ftp --config some/path/config.yml
3. The process will generate a default config file and exit with a usage notice
4. edit the default config file and provide connection details for Amazon S3
5. Upload a passwd file to your S3 bucket. It should contain a single line
   per user and be a CSV. It should look something like this

  user1,password,y
  user2,password,n

  the third column indicatest he users administrator status. Administrators can
  see all files. Regular users are sandboxed to their own directory.

  if you enable bcrypt encryption support, you can generate the password hash by running 
  ruby -e "require 'bcrypt' ; mypass = BCrypt::Password.create('password') ; puts mypass"

6. As root if you choose a listening port less than 1024, or as any other user otherwise , run s3ftp --config some/path/config.yml again

## License

This library is distributed under the terms of the MIT License. See the included file for
more detail.
