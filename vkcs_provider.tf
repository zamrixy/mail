
terraform {
    required_providers {        
		openstack = {
            source  = "terraform-provider-openstack/openstack"
            version = "~> 1.46.0"
        }

        vkcs = {
            source = "vk-cs/vkcs"
            version = "~> 0.1.12"
        }

    }
}

provider "vkcs" {
    # Your user account.
    username = "maserati_1@mail.ru"

    # The password of the account
    password = "Kol-1Kut-2Kak-3"

    # The tenant token can be taken from the project Settings tab - > API keys.
    # Project ID will be our token.
    project_id = "5c051da5877d4a11b3a22f8f8f0c8729"

    # Region name
    region = "RegionOne"

    auth_url = "https://infra.mail.ru:35357/v3/"
}
    
