# Sysinfo Queries
This document gives you instructions on how to provide relevant information for 
support enquiries when reporting issues with your Crate installation.

So we've built a tool which finds what you don't know you're looking for. All 
you need to do is copy/paste the output into the email.

*Here's how it works:*

## Provide system/cluster information

You can generate the report by simply running crash with the --sysinfo argument:

```bash
$ crash --sysinfo --hosts example.com:4200
```

## Run external queries
If you have a lower version of Crash (< 0.15) or Crate (< 0.54) you can also 
try to run our external sysinfo-queries which is hosted on this repo.  

This statement fetches the latest query from the official Repo and redirectes 
them into your local Crash where it gets executed.

```bash
curl -L https://raw.githubusercontent.com/crate/crate-utils/master/sysinfo/sysinfo_queries.sql | crash --hosts localhost:4200 --format dynamic
```
