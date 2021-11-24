# puppet_hiera_example
A fully functional example repository that demonstrates how to use Hiera to build up node classifications by making use of Puppet's trusted certificate extensions.

This repository can also be used as a template to help you quickly get started with using Puppet in your own environment.

# How it all works
When Puppet nodes request their certificates they have the option to embed additional data in the certificate signing request which then become trusted facts. (You can read more about CSR extensions in the [Puppet docs](https://puppet.com/docs/puppet/7/ssl_attributes_extensions.html))  
We take advantage of this by using `pp_service`, `pp_role` and `pp_environment` to allow us to define node roles within hiera, this in turn allows us to develop reusable modules which can quickly be deployed to a single node or the entire estate!

# Hiera-eyaml
This repo makes use of [hiera-eyaml](https://github.com/voxpupuli/hiera-eyaml) to encrypt sensitive values within the configuration data stored in Hiera.  
To be able to encrypt and decrypt these values you need a key value pair, one has been provided in the `keys` directory for demonstration purposes but this should absolutely **NOT** be used in production.  
To generate your own:
* `gem install hiera-eyaml`
* `eyaml createkeys`
* Copy the values `private_key.pkcs7.pem` and `public_key.pkcs7.pem` to your Puppetserver 

Where you copy them to depends on your values for `pkcs7_private_key` and `pkcs7_public_key` in your `hiera.yaml` file. (for this example repo that's `/etc/puppetlabs/puppet/keys`)

>⚠️ Make sure you have a copy of `private_key.pkcs7.pem` stored somewhere safe (like a password manager) that way if you ever lose your Puppetserver then you can still read your secrets!