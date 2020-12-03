<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
    <head>
        <title>Nextcloud VM</title>
        <META NAME="ROBOTS" CONTENT="NOINDEX, NOFOLLOW">
        <style type="text/css">
            body {
                background-color: #0082c9;
                font-weight: 300;
                font-size: 1em;
                line-height: 1.6em;
                font-family: 'Open Sans', Frutiger, Calibri, 'Myriad Pro', Myriad, sans-serif;
                color: white;
                height: auto;
                margin-left: auto;
                margin-right: auto;
                align: center;
                text-align: center;
                background: #0082c9; /* Old browsers */
                background-image: url('/nextcloud/core/img/background.png'), linear-gradient(10deg, #0082c9 0%, rgb(28, 175, 255) 50%);
                background-size: cover;
            }
            div.logotext   {
                width: 50%;
                margin: 0 auto;
            }
            div.logo   {
                background-image: url('/nextcloud/core/img/logo/logo.svg');
                background-repeat: no-repeat; top center;
                width: 50%;
                height: 25%;
                margin: 0 auto;
                background-size: 40%;
                margin-left: 40%;
                margin-right: 20%;
            }
            pre  {
                padding:10pt;
                width: 50%
                text-align: center;
                margin-left: 20%;
                margin-right: 20%;
            }
            div.information {
                align: center;
                width: 50%;
                margin: 10px auto;
                display: block;
                padding: 10px;
                background-color: rgba(0,0,0,.3);
                color: #fff;
                text-align: left;
                border-radius: 3px;
                cursor: default;
            }
            /* unvisited link */
            a:link {
                color: #FFFFFF;
            }
            /* visited link */
            a:visited {
                color: #FFFFFF;
            }
            /* mouse over link */
            a:hover {
                color: #E0E0E0;
            }
            /* selected link */
            a:active {
                color: #E0E0E0;
            }
        </style>
    </head>
    <body>
        <br>
        <div class="logo"></div>
        <div class="logotext">
            <h2><a href="https://github.com/nextcloud/vm" target="_blank">Nextcloud VM</a> - by <a href="https://www.hanssonit.se/nextcloud-vm/" target="_blank">T&M Hansson IT AB</a></h2>
        </div>
        <br>
        <div class="information">
            <p>Thank you for downloading the Nextcloud VM, you made a good choice! If you see this page, you have run the first setup, and you are now ready to start using Nextcloud on your new server. Congratulations! :)</p>
            <p>We have prepared everything for you, and the only thing you have to do now is to login. You can find login details further down in this page.</p>
            <p>Don't hesitate to ask if you have any questions. You can ask for help in our community <a href="https://help.nextcloud.com/c/support/appliances-docker-snappy-vm" target="_blank">support</a> channels, or <a href="https://shop.hanssonit.se/product/premium-support-per-30-minutes/" target="_blank">buy hands on support</a> from T&M Hansson IT AB. You can also check the <a href="https://docs.hanssonit.se/s/W6fMouPiqQz3_Mog/virtual-machines-vm/d/W7Du9uPiqQz3_Mr1/nextcloud-vm-machine-configuration" target="_blank">documentation</a>.</p>
        </div>

        <h2>Access Nextcloud</h2>

        <div class="information">
            <p>Use the following address:
            <h3>
                <ul>
                    <li><a href="https://<?=$_SERVER['SERVER_NAME'];?>">https://<?=$_SERVER['SERVER_NAME'];?></a> (HTTPS)
                </ul>
            </h3>
            <p>Note: Please accept the warning in the browser if you have a self-signed certificate.<br>

            <p>It's recommended to <a href="https://docs.hanssonit.se/s/W6fMouPiqQz3_Mog/virtual-machines-vm/d/W6-83ePiqQz3_MrT/publish-your-server-online" target="_blank">get your own certificate and replace the self-signed certificate to your own.</a>
            The easiest way to get a real TLS certificate is to run the Lets' Encrypt script included on this server.<br>
            Just run 'sudo bash /var/scripts/menu.sh' from your CLI and choose Server Configuration --> Activate TLS.
            <h3>
                <a href="https://docs.hanssonit.se/s/W6fMouPiqQz3_Mog/virtual-machines-vm/d/W6fMquPiqQz3_Moi/nextcloud-vm-first-setup-instructions?currentPageId=W6yo9OPiqQz3_Mpy" target="_blank">Login details</a>
            </h3>
        </div>

        <h2>Access Webmin</h2>

        <div class="information">
            <p>Use the following address:
            <h3>
                <ul>
                    <li><a href="https://<?=$_SERVER['SERVER_NAME'];?>:10000">https://<?=$_SERVER['SERVER_NAME'];?></a> (HTTPS)</li>
                </ul>
	    </h3>
	    <p>Note: Please accept the warning in the browser if you have a self-signed certificate.<br>
            <h3>
	        <a href="https://docs.hanssonit.se/s/W6fMouPiqQz3_Mog/virtual-machines-vm/d/W6fMquPiqQz3_Moi/nextcloud-vm-first-setup-instructions?currentPageId=W6yn_ePiqQz3_Mpk" target="_blank">Login details</a>
            </h3>
            <p>Note: To access Webmin externally you have to open port 10000 in your router, it's not recommended though due to security concerns.</p>
        </div>

        <h2>Access Adminer</h2>

        <div class="information">
            <p>Use the following address:
            <h3>
                <ul>
                    <li><a href="https://<?=$_SERVER['SERVER_NAME'];?>:9443">https://<?=$_SERVER['SERVER_NAME'];?>:9443</a> (HTTPS)</li>
                </ul>
            </h3>
            <p>Note: Please accept the warning in the browser if you have a self-signed certificate.<br>
            <h3>
                <a href="https://docs.hanssonit.se/s/W6fMouPiqQz3_Mog/virtual-machines-vm/d/W6fMquPiqQz3_Moi/nextcloud-vm-first-setup-instructions?currentPageId=W6ypBePiqQz3_Mp0" target="_blank">Login details</a>
            </h3>
            <p>Note: Your LAN IP is set as approved in /etc/apache2/sites-available/adminer.conf, all other access is forbidden.</p>
        </div>

        <h2>Follow us on Social Media</h2>

        <div class="information">
            <p>If you want to get the latest news and updates, please consider following us! We are very active on Twitter, and post some videos from time to time on Youtube. It might be worth checking out. ;)</p>
        </div>
            <p><b><a href="https://twitter.com/tmhanssonit" class="twitter-follow-button" data-show-count="false" target="_blank">Follow @tmhanssonit</a><script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script></b></p>
            <script src="https://apis.google.com/js/platform.js"></script>
            <div class="g-ytsubscribe" data-channelid="UCLXe8RpVdOsoapYM9_GcrfA" data-layout="full" data-count="default"></div>
    </body>
</html>
