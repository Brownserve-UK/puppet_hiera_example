# puppet_hiera_example
A fully functional example repository that demonstrates how to use Hiera to build up node classifications by making use of Puppet's trusted certificate extensions.

This repository can also be used as a template to help you quickly get started with using Puppet in your own environment.

# How it all works
When Puppet nodes request their certificates they have the option to embed additional data in the certificate signing request which then become trusted facts. (You can read more about CSR extensions in the [Puppet docs](https://puppet.com/docs/puppet/7/ssl_attributes_extensions.html))  
We take advantage of this by using `pp_service`, `pp_role` and `pp_environment` to allow us to define node roles within hiera, this in turn allows us to develop reusable modules which can quickly be deployed to a single node or the entire estate!