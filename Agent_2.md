## FLOW FOR RENTAL PAK HAJI 
## FLOW USER 

## User Story 

> Disini bisa membuat User Baru Untuk User Customer yang bisa create order nya , jadi fill nya ada Nama Lengkap, Tanggal Tahun lahir, Alamat, Nomor handphone, email, foto ktp, foto sim A, 

> lalu pada sisi operational akan mendifined apakah customer itu terverified untuk sebagai member dan bisa order untuk selfdrive, kalau belum terverified user hanya bisa order with driver saja, lalu ada juga flag untuk user blocked disisi ini user tidak bisa order service type apapunn with driver maupun self drive karen customer nya sudah di block

> Lalu buat akun untuk sisi operational, dengan fill Nama lengkap, Tanggal tahun lahir, alamat, nomor handphone, email, foto ktp. nah disini ada roles nya bisa di set 
> apakah atas user si A super admin yang bisa akses semua nya dari create sampai sisi operational nya 
> lalu ada juga hanya bisa sisi operational nya roles nya tidak bisa create order untuk customer nya, kemudian dari user ini terbentuk lah generate token nya untuk bearer token antara api nya yang menjadi headers nya, auth token ini tergenerate ketika login awal dan akan di bawa kemana mana, untuk masa valid nya bikin 1 hari kalau sudah 1 hari maka tidak valid dan perlu login ulang untuk membentuk token baru 


