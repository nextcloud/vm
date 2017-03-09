<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
    <head>
        <title>Nextloud VM</title>
        <META NAME="ROBOTS" CONTENT="NOINDEX, NOFOLLOW">
        <style>
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
                background-image: url('https://raw.githubusercontent.com/nextcloud/server/master/core/img/background.jpg');
                background-size: cover;
            }
            div.logotext   {
                width: 50%;
                margin: 0 auto;
            }
            div.logo   {
                background-image: url('/nextcloud/core/img/logo-icon.svg');
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
            <h2><a href="https://github.com/techandme/NextBerry" target="_blank">NextBerry</a> - by <a href="https://www.techandme.se" target="_blank">Tech And Me</a></h2>
        </div>
        <br>
        <div class="information">
            <p>Thank you for downloading the NextBerry! If you see this page, you have successfully installed Nextcloud on your RaspberryPI.</p>
            <p>We have set everything up for you and the only thing you have to do now is to login. You can find login details in the middle of this page.
            <p>Don't hesitate to ask if you have any questions. You can ask for help on github <a href="https://github.com/techandme/NextBerry/issues/new" target="_blank">support</a> channels. You can also check the <a href="https://www.techandme.se/complete-install-instructions-nextcloud/" target="_blank">complete install instructions</a>.</p>
        </div>

        <h2><a href="https://www.techandme.se/user-and-password-nextcloud/" target="_blank">Login</a> to Nextcloud</h2>

        <div class="information">
            <p>Default User:</p>
            <h3>ncadmin</h3>
            <p>Default Password:</p>
            <h3>nextcloud</h3>
            <p>Note: The setup script will ask you to change the default password to your own. It's also recommended to change the default user. Do this by adding another admin user, log out from ncadmin, and login with your new user, then delete ncadmin.</p>
            <br>
            <center>
                <h3> How to mount the VM and and login:</h3>
            </center>
            <p>Before you can use Nextcloud you have to run the setup script to complete the installation. This is easily done by just typing 'nextcloud' when you log in to the terminal for the first time.</p>
            <p>The full path to the setup script is: /var/scripts/nextcloud-startup-script.sh. When the script is finished it will be deleted, as it's only used the first time you boot the machine.</p>
            <center>
                <iframe width="560" height="315" src="https://www.youtube.com/embed/-3fKEu2HhJo" frameborder="0" allowfullscreen></iframe>
            </center>
        </div>

        <h2>Access Nextcloud</h2>

        <div class="information">
            <p>Use one of the following addresses, HTTPS is preffered:
            <h3>
                <ul>
                    <li><a href="http://<?=$_SERVER['SERVER_NAME'];?>/nextcloud">http://<?=$_SERVER['SERVER_NAME'];?></a> (HTTP)
                    <li><a href="https://<?=$_SERVER['SERVER_NAME'];?>/nextcloud">https://<?=$_SERVER['SERVER_NAME'];?></a> (HTTPS)
                </ul>
            </h3>
            <p>Note: Please accept the warning in the browser if you connect via HTTPS. It is recommended<br>
            to <a href="https://www.techandme.se/publish-your-server-online" target="_blank">buy your own certificate and replace the self-signed certificate to your own.</a><br>
            <p>Note: Before you can login you have to run the setup script, as descirbed in the video above.
        </div>

        <h2>Access phpMyadmin</h2>

        <div class="information">
            <p>Use one of the following addresses, HTTPS is preffered:
            <h3>
                <ul>
                    <li><a href="http://<?=$_SERVER['SERVER_NAME'];?>/phpmyadmin">http://<?=$_SERVER['SERVER_NAME'];?></a> (HTTP)
                    <li><a href="https://<?=$_SERVER['SERVER_NAME'];?>/phpmyadmin">https://<?=$_SERVER['SERVER_NAME'];?></a> (HTTPS)
                </ul>
            </h3>
            <p>Note: Please accept the warning in the browser if you connect via HTTPS.</p>
            <h3>
                <a href="https://www.techandme.se/user-and-password-nextcloud/" target="_blank">Login details</a>
            </h3>
            <p>Note: Your external IP is set as approved in /etc/apache2/conf-available/phpmyadmin.conf, all other access is forbidden.</p>
        </div>
    </body>
</html>
