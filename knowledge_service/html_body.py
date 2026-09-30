"""Xidian CMS body adapters and explicit (never guessed) publication dates."""
import json
import re
import base64
import zlib
from urllib.parse import urljoin, urlsplit
from lxml import html
from .attachments import ocr_images

OCR_IMAGE_CUES=("工作时间","开放时间","收费标准","联系电话","办理流程","服务流程","时刻表","排班")


def parse_html(data,url):
    # lxml decodes from the page's declared encoding; keep parsing independent
    # of trafilatura for the CMS article formats handled below.
    tree=html.fromstring(data)
    tree.make_links_absolute(url)
    title_nodes=tree.xpath('//meta[@name="pageTitle"]/@content | //title/text()')
    title=next((str(x).strip() for x in title_nodes if str(x).strip()),'')
    if not title:
        raise ValueError('原文标题缺失')
    raw_text=' '.join(tree.xpath('//text()[not(ancestor::script) and not(ancestor::style)]'))
    metadata=tree.xpath('//meta[@property="article:published_time" or @name="PubDate" or @name="publishdate"]/@content')
    match=re.search(r'(?:发布时间|发布日期|发布时间：|时间|日期)\s*[:：]\s*(20\d{2})[-年./](\d{1,2})[-月./](\d{1,2})',raw_text)
    published=f'{int(match[1]):04d}-{int(match[2]):02d}-{int(match[3]):02d}' if match else None
    header_dates=tree.xpath('//*[contains(concat(" ",normalize-space(@class)," ")," zd ")]//text()')
    for value in header_dates:
        match=re.search(r'(20\d{2})[-年./](\d{1,2})[-月./](\d{1,2})',str(value))
        if match:
            published=f'{int(match[1]):04d}-{int(match[2]):02d}-{int(match[3]):02d}'
            break
    if metadata and re.match(r'20\d{2}-\d{2}-\d{2}',metadata[0]):
        published=metadata[0][:10]
    image_data=re.search(rb'var\s+vsb_pdf_image_data\s*=\s*(\[[^;]+\])',data)
    encoded_article=re.search(rb'Base64\.decode\(\s*unzip\([\'"]([^\'"]+)',data)
    pages=None
    if image_data:
        urls=[urljoin(url,path) for path in json.loads(image_data[1])]
        from .ingest import official_url
        if not all(official_url(target) for target in urls):
            raise ValueError('图像正文来源不在官方范围内')
        pages=ocr_images(urls)
        text='\n\n'.join(body for _,body in pages)
    elif urlsplit(url).hostname=='job.xidian.edu.cn' and encoded_article:
        # The employment portal stores article HTML as base64 inside a zlib
        # payload and leaves the visible article node empty until JavaScript runs.
        packed=base64.b64decode(encoded_article[1])
        unpacked=zlib.decompress(packed).decode('utf-8','replace')
        encoded=unpacked.removeprefix('view2d').strip()
        article_html=base64.b64decode(encoded).decode('utf-8','replace')
        article_html=article_html.removeprefix('view1d').strip()
        node=html.fragment_fromstring(article_html,create_parent='div')
        for unwanted in node.xpath('.//script|.//style'):
            unwanted.drop_tree()
        for anchor in node.xpath('.//a[@href]'):
            target=urljoin(url,anchor.get('href'))
            anchor.text=(anchor.text or '')+' ('+target+')'
        for row in node.xpath('.//tr'):
            row.text=' | '.join(' '.join(cell.itertext()).strip() for cell in row.xpath('./th|./td'))
            for child in list(row):
                row.remove(child)
            row.tail='\n'
        for element in node.xpath('.//p|.//div|.//br|.//li|.//h1|.//h2|.//h3'):
            element.tail='\n'+(element.tail or '')
        text=node.text_content().strip()
    else:
        # Some Xidian pages embed a converted DOCX inside the CMS article. The
        # outer node contains the converter's CSS, while the inner article is
        # the actual policy text.
        nodes=tree.xpath('//section[contains(concat(" ",normalize-space(@class)," ")," docx ")]//article | //section[contains(concat(" ",normalize-space(@class)," ")," docx ")] | //*[@id="vsb_content" or @id="vsb_content_2" or contains(concat(" ",normalize-space(@class)," ")," v_news_content ")]')
        # Network-center service pages put procedures/materials beside the CMS introduction.
        if urlsplit(url).hostname=='xxzx.xidian.edu.cn' and tree.xpath('//div[contains(concat(" ",normalize-space(@class)," ")," list01 ")]'):
            nodes=tree.xpath('//div[contains(concat(" ",normalize-space(@class)," ")," list01 ")]')
        elif urlsplit(url).hostname=='tyb.xidian.edu.cn' and urlsplit(url).path.startswith('/cggl'):
            nodes=tree.xpath('//div[contains(concat(" ",normalize-space(@class)," ")," main_con_r ")]')
        if nodes:
            node=nodes[0]
            for unwanted in node.xpath('.//script|.//style'):
                unwanted.drop_tree()
            # CMS boundaries identify the article; keep its paragraphs, tables and actual links.
            for anchor in node.xpath('.//a[@href]'):
                target=anchor.get('href')
                if target.startswith(('http://','https://')):
                    anchor.text=(anchor.text or '')+' ('+target+')'
            for row in node.xpath('.//tr'):
                row.text=' | '.join(' '.join(cell.itertext()).strip() for cell in row.xpath('./th|./td'))
                for child in list(row):
                    row.remove(child)
                row.tail='\n'
            for element in node.xpath('.//p|.//div|.//br|.//li|.//h1|.//h2|.//h3'):
                element.tail='\n'+(element.tail or '')
            text=node.text_content().strip()
            image_urls=list(dict.fromkeys(node.xpath('.//img/@src')))
            if image_urls and (len(text)<80 or any(cue in text for cue in OCR_IMAGE_CUES)):
                from .ingest import official_url
                official_images=[target for target in image_urls if official_url(target)]
                if len(text)<80 and len(official_images)!=len(image_urls):
                    raise ValueError('图像正文来源不在官方范围内')
                if official_images:
                    image_pages=ocr_images(official_images)
                    image_text='\n\n'.join(body for _,body in image_pages if body.strip())
                    if image_text:
                        text+='\n\n图片正文 OCR：\n'+image_text
        else:
            for unwanted in tree.xpath('//script|//style|//header|//nav|//footer|//aside|//*[contains(concat(" ",normalize-space(@class)," ")," part3_lxwm ")]'):
                unwanted.drop_tree()
            try:
                import trafilatura
                extracted=trafilatura.bare_extraction(html.tostring(tree),url=url,
                    include_tables=True,include_links=True,include_comments=False,with_metadata=False,favor_precision=True)
                text=extracted.text.strip() if extracted and extracted.text else ''
            except ImportError:
                body=tree.xpath('//main|//article|//*[@id="vsb_content"]|//body')
                text=body[0].text_content().strip() if body else ''
    if re.search(r'无法在线浏览此\s*PDF\s*文件|下载此\s*PDF\s*文件',text,re.I):
        content_nodes=tree.xpath('//*[@id="vsb_content" or @id="vsb_content_2" or contains(concat(" ",normalize-space(@class)," ")," v_news_content ")]')
        scope=content_nodes[0] if content_nodes else tree
        pdf_urls=list(dict.fromkeys(
            target for value in scope.xpath('.//iframe/@src|.//object/@data|.//embed/@src|.//a/@href')
            for target in [urljoin(url,value)]
            if urlsplit(target).path.lower().endswith('.pdf')
        ))
        if pdf_urls:
            from .attachments import extract_pdf_pages
            from .ingest import official_url
            import requests
            target=pdf_urls[0]
            if not official_url(target):
                raise ValueError('PDF 正文来源不在官方范围内')
            response=requests.get(target,timeout=(10,30),headers={
                'User-Agent':'ZhixingKnowledge/2.0 (+https://zhixing.xidian.edu.cn)'})
            response.raise_for_status()
            if not official_url(response.url):
                raise ValueError('PDF 重定向到来源范围以外')
            pages=extract_pdf_pages(response.content)
            text='\n\n'.join(body for _,body in pages)
            if len(text.strip())<80:
                raise ValueError('嵌入 PDF 正文与 OCR 均无可用文字')
    text='\n'.join(line.strip() for line in text.splitlines() if line.strip())
    if len(text)<80:
        raise ValueError('正文不足，需检查图片、附件或访问权限')
    return title,text,published,pages
