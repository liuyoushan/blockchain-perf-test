FROM python:3.10-slim
WORKDIR /app
COPY chain_exporter.py .
RUN pip install flask
EXPOSE 9100
CMD ["python", "chain_exporter.py"]
