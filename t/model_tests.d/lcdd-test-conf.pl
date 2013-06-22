
$conf_file_name = "LCDd.conf" ;
$conf_dir = "etc" ;
$model_to_test = "LCDd" ;

my @fix_warnings ;

push @fix_warnings,
    ( 
        #load_warnings => [ qr/code check returned false/ ],
        load => "server DriverPath=/tmp/" , # just a work-around
    ) 
    unless -d '/usr/lib/lcdproc/' ;

@tests = (
    { # t0
     check => { 
       'server Hello:0',           qq!"  Bienvenue"! ,
       'server Hello:1',           qq("   LCDproc et Config::Model!") ,
       'server GoodBye:0',           qq!"    GoodBye"! ,
       'server GoodBye:1',           qq("    LCDproc!") ,
       'server Driver', 'curses',
       'curses Size', '20x2',
     },
     @fix_warnings ,
     errors => [ 
            # qr/value 2 > max limit 0/ => 'fs:"/var/chroot/lenny-i386/dev" fs_passno=0' ,
        ],
    },
    {   #test upgrade from raw lcdproc 0.5.5
        name => 'LDCd-0.5.5',
        load_check => 'skip'
    },
    {   # likewise for lcdproc 0.5.6
        name => 'LDCd-0.5.6',
        load_check => 'skip'
    },
    
);

1;
