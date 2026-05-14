# PsiphonOverMITM

**یک لانچر ساده و آماده برای اجرای Psiphon over MITM روی ویندوز**

[![Windows](https://img.shields.io/badge/Windows-10%2F11-0078D4.svg?style=for-the-badge&logo=windows)]()
[![Core](https://img.shields.io/badge/Core-Xray_26.4.25-black.svg?style=for-the-badge)]()
[![Mode](https://img.shields.io/badge/Mode-Psiphon_Upstream_Proxy-2ea44f.svg?style=for-the-badge)]()
[![Author](https://img.shields.io/badge/by-%40b3hnamrjd-blue.svg?style=for-the-badge)](https://github.com/B3hnamR/PsiphonOverMITM)

<p align="center">
📣 جهت دریافت اطلاعات و نکات بیشتر به کانال تلگرامی من مراجعه کنید: <a href="https://t.me/B3hnamR">@B3hnamR</a>.
</p>

<p align="center">
⭐ اگر این پروژه براتون مفید بود، Star یادتون نره.
</p>

---

## داستان این پروژه چیه؟

این پروژه برای وقتی ساخته شده که می‌خوای Psiphon را با یک upstream proxy محلی اجرا کنی، اما آن upstream خودش از تکنیک MITM-DomainFronting استفاده کند. خیلی ساده‌تر بگم: به جای اینکه Psiphon مستقیم تلاش کند وصل شود، اول درخواستش را به یک Xray محلی می‌دهد؛ Xray با کانفیگ مخصوص Patterniha مسیرهای لازم را باز می‌کند، بعد Psiphon از همان مسیر جلو می‌رود.

اسم درست معماری این حالت:

```text
Psiphon over MITM
```

چون Psiphon روی MITM سوار می‌شود، نه برعکس.

این پروژه قرار نیست کل اینترنت را جادویی باز کند. هدفش این است که یک helper تمیز و قابل‌مدیریت برای اجرای کانفیگ `psiphon-helper@patterniha.json` روی ویندوز داشته باشی؛ با Start و Stop ساده، لاگ قابل‌فهم، certificate خودکار و خروجی واضح برای تنظیمات Psiphon.

---

## تشکر و اعتبار

هسته اصلی ایده، کانفیگ‌ها و روش MITM-DomainFronting متعلق به **Patterniha** است.  
لطفاً ریپوی اصلی را ببینید و از پروژه اصلی حمایت کنید:

[https://github.com/patterniha/MITM-DomainFronting](https://github.com/patterniha/MITM-DomainFronting)

این ابزار فقط یک بسته‌بندی ویندوزی و لانچر ساده‌تر برای اجرای همان معماری در حالت مخصوص Psiphon است.

---

## تو این نسخه چه خبره؟

- **اجرای یک‌کلیکی Psiphon helper:** فایل `psiphon-helper@patterniha.json` مستقیم با Xray داخلی اجرا می‌شود.
- **Certificate خودکار طبق آموزش Patterniha:** اگر `mycert.crt` و `mycert.key` وجود نداشته باشند، با `certificate_generator.bat` نسخه v14 ساخته می‌شوند.
- **نصب امن certificate روی Local Machine:** فقط `mycert.crt` به Trusted Root اضافه می‌شود؛ `mycert.key` خصوصی می‌ماند.
- **پورت آماده برای Psiphon:** خروجی نهایی بهت می‌گوید در Psiphon چه upstream proxy بزنی.
- **لاگ مرحله‌ای:** هر مرحله داخل کنسول و فایل `PsiphonOverMITM.log` نوشته می‌شود.
- **بدون دست‌کاری Windows Proxy:** این پروژه برای upstream proxy سایفون است، نه set system proxy ویندوز.
- **Stop تمیز:** PID ذخیره می‌شود و Stop فقط همان Xray مربوط به این پروژه را می‌بندد.

---

## معماری دقیق چطوری کار می‌کنه؟

مسیر کلی این شکلیه:

```text
Psiphon
  -> Upstream Proxy: 127.0.0.1:20808
  -> Xray local mixed inbound
  -> MITM tunnel / TLS repack
  -> Akamai / Fastly fronting routes
  -> Psiphon connection
```

یعنی Psiphon فکر می‌کند دارد از یک proxy محلی استفاده می‌کند. آن proxy محلی همان Xray است که با کانفیگ `psiphon-helper@patterniha.json` بالا آمده. Xray درخواست‌های TLS را می‌گیرد، با certificate شخصی شما MITM می‌کند، بعد طبق routeهای داخل کانفیگ، ترافیک را با SNI/Front مناسب به مقصد قابل دسترس می‌فرستد.

پس اگر بخوای خیلی کوتاه توضیح بدی:

```text
Psiphon first connects to local MITM, then MITM helps Psiphon reach its network.
```

---

## فایل‌های مهم پروژه

| فایل / فولدر | توضیح |
| :--- | :--- |
| `Run-PsiphonOverMITM.bat` | فایل اصلی اجرای ویندوزی |
| `PsiphonOverMITM.ps1` | اسکریپت اصلی مدیریت Start / Stop / Status |
| `psiphon-helper@patterniha.json` | کانفیگ مخصوص Psiphon از Patterniha |
| `xray/xray.exe` | هسته Xray داخلی پروژه |
| `xray/mycert.crt` | certificate عمومی شخصی شما |
| `xray/mycert.key` | private key شخصی شما، نباید به کسی داده شود |
| `MITM-DomainFronting-14/Xray-config/certificate_generator.bat` | generator رسمی مورد استفاده برای ساخت certificate |
| `runtime/` | فایل‌های runtime، pid، config موقت و لاگ‌های اجرای Xray |
| `PsiphonOverMITM.log` | لاگ قابل خواندن مراحل اجرای اسکریپت |

---

## نصب و اجرای سریع روی ویندوز

برای رفقایی که نمی‌خوان با ترمینال درگیر بشن، مسیر استفاده اینه:

1. پروژه را Extract کن.
2. روی `Run-PsiphonOverMITM.bat` راست‌کلیک کن.
3. گزینه **Run as administrator** را بزن.
4. از منو گزینه `[1] Start` را انتخاب کن.
5. صبر کن تا پیام نهایی را ببینی.

اگر همه‌چیز درست باشد، خروجی شبیه این می‌شود:

```text
PsiphonOverMITM is active.
Set Psiphon upstream proxy to: 127.0.0.1:20808
```

حالا داخل Psiphon در بخش upstream proxy بزن:

```text
Host: 127.0.0.1
Port: 20808
```

نکته مهم: اگر ویندوز روی سیستم تو اجازه bind روی `20808` ندهد، اسکریپت خودش پورت جایگزین می‌دهد. در آن حالت حتماً همان پورتی را که اسکریپت چاپ کرده داخل Psiphon وارد کن.

---

## منوی برنامه

بعد از اجرای فایل bat این منو را می‌بینی:

```text
[1] Start
[2] Stop
[3] Status
[0] Exit
```

### `[1] Start`

همه‌چیز را آماده می‌کند:

- Xray را چک می‌کند.
- پورت local upstream را آماده می‌کند.
- کانفیگ runtime را از `psiphon-helper@patterniha.json` می‌سازد.
- certificate شخصی را می‌سازد یا اگر وجود دارد همان را نگه می‌دارد.
- `mycert.crt` را در Local Machine Trusted Root نصب می‌کند.
- Xray را با کانفیگ Psiphon helper اجرا می‌کند.
- در آخر آدرس و پورت لازم برای Psiphon را چاپ می‌کند.

### `[2] Stop`

Xray مربوط به همین پروژه را stop می‌کند و PID runtime را پاک می‌کند.

### `[3] Status`

وضعیت را نشان می‌دهد:

```text
PsiphonOverMITM: running
Proxy: 127.0.0.1:20808 reachable=True
Log: ...\PsiphonOverMITM.log
```

اگر `reachable=False` بود، یعنی Psiphon هنوز نمی‌تواند به helper وصل شود. اول Stop بزن، بعد دوباره Start کن و پورت چاپ‌شده را دقیق وارد کن.

---

## Certificate دقیقاً چه کاری می‌کند؟

طبق آموزش Patterniha، برای MITM نیاز به یک certificate شخصی داری. این پروژه دقیقاً همان روند را خودکار می‌کند.

وقتی Start می‌زنی:

1. اگر `xray/mycert.crt` و `xray/mycert.key` وجود داشته باشند، همان‌ها استفاده می‌شوند.
2. اگر وجود نداشته باشند، اسکریپت از این فایل استفاده می‌کند:

```text
MITM-DomainFronting-14/Xray-config/certificate_generator.bat
```

و دو فایل می‌سازد:

```text
xray/mycert.crt
xray/mycert.key
```

بعد فقط `mycert.crt` داخل ویندوز نصب می‌شود:

```text
Local Machine -> Trusted Root Certification Authorities
```

`mycert.key` نصب نمی‌شود. این فایل private key توست و باید فقط روی سیستم خودت بماند.

**هشدار خیلی مهم:**  
`mycert.crt` را از کسی نگیر.  
`mycert.key` را به هیچ‌کس نده.  
اگر certificate/key را از جای نامطمئن بگیری، عملاً به آن شخص اجازه دادی ترافیک TLS تو را جعل و inspect کند.

---

## آیا certificate برای یک کانفیگ خاصه؟

نه. این certificate به یک کانفیگ خاص مثل Netlify یا Psiphon قفل نشده. این یک Root CA شخصی برای MITM است. هر کانفیگی که داخل Xray از این دو فایل استفاده کند:

```text
mycert.crt
mycert.key
```

می‌تواند certificateهای جعلی لازم را برای MITM تولید کند. برای همین نصب چند certificate مختلف بدون دلیل خوب نیست. این پروژه اگر certificate قبلی وجود داشته باشد، دوباره certificate جدید نمی‌سازد؛ همان را نگه می‌دارد و فقط trusted بودنش را چک می‌کند.

---

## چرا Administrator لازم است؟

دو دلیل اصلی دارد:

- نصب `mycert.crt` داخل `Local Machine Trusted Root` نیاز به دسترسی Administrator دارد.
- اجرای تمیز و قابل‌اعتماد Xray و مدیریت PID روی ویندوز بهتر است با دسترسی کامل انجام شود.

اگر بدون Administrator اجرا کنی، برنامه بهت هشدار می‌دهد و ادامه نمی‌دهد.

---

## چرا Windows Proxy تنظیم نمی‌شود؟

چون این پروژه مخصوص Psiphon است. ما نمی‌خواهیم کل سیستم را proxy کنیم. فقط می‌خواهیم Psiphon در تنظیمات خودش از این upstream استفاده کند.

تنظیم درست داخل Psiphon:

```text
Upstream proxy host: 127.0.0.1
Upstream proxy port: 20808
```

یا هر پورتی که برنامه بعد از Start چاپ کرد.

---

## لاگ‌ها کجا هستند؟

لاگ اصلی:

```text
PsiphonOverMITM.log
```

لاگ‌های runtime Xray:

```text
runtime/PsiphonOverMITM.out.log
runtime/PsiphonOverMITM.err.log
```

اگر اتصال Psiphon fail شد، اول Status را بزن. بعد فایل‌های log را چک کن. معمولاً مشکل یکی از این‌هاست:

- پورت را داخل Psiphon اشتباه وارد کردی.
- به جای `127.0.0.1` چیز دیگری زدی.
- helper خاموش است.
- ویندوز اجازه استفاده از `20808` نداده و برنامه پورت جایگزین داده.
- certificate نصب نشده یا با دستکاری دستی خراب شده.
- Psiphon هنوز روی upstream proxy قبلی مانده.

---

## خطاهای رایج

| خطا | معنی ساده | راه‌حل |
| :--- | :--- | :--- |
| `reachable=False` | helper روی آن پورت گوش نمی‌دهد | Start بزن و پورت چاپ‌شده را وارد کن |
| `Administrator access is required` | فایل را عادی اجرا کردی | Run as administrator بزن |
| `Certificate generation failed` | generator نتوانسته cert بسازد | وجود `xray/xray.exe` و فایل generator را چک کن |
| `Xray config validation failed` | JSON یا نسخه Xray مشکل دارد | Xray 26.4.25 و فایل helper درست را استفاده کن |
| `Upstream Proxy Error` در Psiphon | Psiphon به helper وصل شده ولی مسیر جواب نداده یا پورت غلط است | Status بزن، پورت را چک کن، Psiphon را restart کن |

---

## ساختار تمیز اجرای خام

اگر می‌خوای از صفر تست بگیری:

1. Stop بزن.
2. اگر لازم بود فقط فایل‌های runtime را پاک کن.
3. فایل‌های `mycert.crt` و `mycert.key` را فقط وقتی پاک کن که واقعاً می‌خوای certificate جدید بسازی.
4. دوباره `Run-PsiphonOverMITM.bat` را با Administrator اجرا کن.
5. Start بزن.
6. پورت چاپ‌شده را داخل Psiphon وارد کن.

برای استفاده معمولی لازم نیست هر بار certificate را پاک کنی. یک بار ساخت و نصب کافی است.

---

## نکته امنیتی خیلی مهم

MITM یعنی یک Root CA شخصی روی سیستم نصب می‌شود. این کار برای این روش لازم است، ولی باید دقیق و تمیز انجام شود. این پروژه تلاش می‌کند فقط certificate شخصی خودت را بسازد و نصب کند. با این حال مسئولیت نگهداری فایل‌های certificate با خودت است.

فایل زیر را خصوصی نگه دار:

```text
xray/mycert.key
```

اگر این فایل دست کسی بیفتد، دیگر آن certificate امن نیست.

---

## Credits

- MITM-DomainFronting method and configs: [Patterniha](https://github.com/patterniha/MITM-DomainFronting)
- Windows helper and packaging: [@b3hnamrjd](https://github.com/B3hnamR/PsiphonOverMITM)
- Telegram Channel: [B3hnamR](https://t.me/B3hnamR)

---

## جمع‌بندی

اگر بخوام خیلی ساده بگم:

```text
Run-PsiphonOverMITM.bat را با Administrator اجرا کن.
Start بزن.
در Psiphon بزن 127.0.0.1 و پورتی که برنامه چاپ کرده.
وصل شو.
```

همین.
