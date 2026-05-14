# FLOW FOR RENT PAK HAJI 
 ## POV BUSINESS ANALYST

## User Story


> Customer akan membuka website lalu input jenis service (serive type) [1. Self Drive] [2. With Driver] kemudian akan memilih Periode yang akan di pakai #tidak bisa backdate ,  kemudian tekan pesan  lalu pindah halaman akan menampilkan Beberapa Jenis mobil yang available untuk periode tersebut. kemudian cusotmer memilih mobil nya lalu pindah ke menu pembayaran nya lalu dia akan memilih pembayaran via QRIS, Virtual Account, TF Rekening ? setelah dia membayar dia akan menerima email berisi No Order, Jenis Mobil Periode nya, dan invoice nya. 

> Disclaimer Customer Sudah membuat Account Di Rent Pak Haji dan sudah terverifikasi saja yang bisa rental Self Drive

> service type 1. Self Drive Durasi nya harus kelipatan 24 jam yang berarti periode nya harus lebih dari 1 hari, dan serivce type 2. With Driver periode nya hanya ada 4 jam, 6 Jam, 8 jam, 12 jam, 16  jam, dan ada pilihan stay untuk periode beberapa hari nya, dan ada checklist untuk in town/out town nya  

> untuk sisi Operational nya, akan memaintance order yang telah di buat oleh User, seperti Manual Dispatch untuk Vehicle dan Driver, tapi ada AutoDispatch untuk Vehicle dan Driver nya, dan kemudian ada sisi pool in, pool out untuk memulai order nya di trigger dari itu,  dan pool in untuk trigger end order nya, 

> satu sisi ada juga untuk monitoring Unit nya, ada vehicle status untuk menunjukan Unit tersebut status nya [Available, In Order, Breakdown, Theft, Borrow, Disposal] lalu Unit juga dapat di monitoring untuk availbel unit nya, jumlah stock available,  montoring order nya,  monitoring unit yang akan datang dan akan keluar. berlaku juga untuk driver nya, tapi disini akan terfocus bisnis nya pada Self Drive nya 

## [1] Create Order  Self Drive

**Requrired**
- Service Type 
    ---> [1]Self Drive (khusus account yang sudah terverified)
    ---> [2]With Driver 
- Range Order 
    ---> memilih start order nya 
    ---> memilih berapa hari nya 
- Memilih Expedisi (antar ke rumah)/ Mengambil di Pool 
> NEXT (Pesan)

## [2] Payment
- Memilih Tipe Pembayaran
    ---> Virtual Accouint 
    ---> QRIS
    ---> Transfer To Rekening 
- Menunggu hingga selesai di proses dan dapat callback atas pembayaran tersebut 
> SELESAI 
> USER dapat Email Atas pembayaran dan atas Order tersebut 

