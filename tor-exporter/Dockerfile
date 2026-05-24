FROM python:3.12-alpine
RUN pip install --quiet stem
COPY exporter.py /exporter.py
EXPOSE 9320
CMD ["python3", "/exporter.py"]
